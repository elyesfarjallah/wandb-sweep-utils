#!/bin/bash

# W&B Sweep Agent Runner
# Joins an existing W&B sweep and runs agents on any node
# All nodes run identical logic - no master/worker distinction needed
# Usage: ./run_sweep_agent.sh <sweep_id> [gpus_per_agent] [max_runs_per_agent]

set -e

echo "========================================"
echo "W&B Sweep Agent Runner"
echo "========================================"

# Display node information
echo "🖥️  Node: ${SLURMD_NODENAME:-$(hostname)}"
if [ -n "$SLURM_JOB_ID" ]; then
    echo "🆔 SLURM Job ID: $SLURM_JOB_ID"
    echo "📊 Nodes: ${SLURM_NNODES:-1}"  
    echo "🎯 Current task ID: ${SLURM_PROCID:-0}/${SLURM_NTASKS:-1}"
    if [ "${SLURM_PROCID:-0}" -gt 0 ]; then
        echo "⏳ Starting with ${SLURM_PROCID}s delay to stagger output..."
    fi
fi

# Configure rank isolation for independent W&B logging
echo ""
echo "🔧 Configuring rank isolation for independent W&B logging..."
echo "   Current: RANK=${RANK:-not_set}, SLURM_PROCID=${SLURM_PROCID:-not_set}"

# Set rank to 0 to override SLURM_PROCID for Lightning's @rank_zero_only decorator
export RANK=0           # Only this is needed for Lightning's rank detection!

echo "✅ Rank isolation active: RANK=0"
echo "   Each SLURM task will log independently to W&B"
echo ""

# Validate script arguments and set parameters  
echo "📋 Parameter Validation:"
if [ $# -lt 1 ]; then
    echo "❌ Error: Missing required argument"
    echo ""
    echo "Usage: $0 <sweep_id> [gpus_per_agent] [max_runs_per_agent]"
    echo ""
    echo "Arguments:"
    echo "  sweep_id         - W&B sweep ID (required)"
    echo "  gpus_per_agent   - Number of GPUs per agent (default: 1)"
    echo "  max_runs_per_agent - Maximum runs per agent (default: unlimited)"
    echo ""
    echo "Examples:"
    echo "  $0 user/project/abc123                    # 1 GPU per agent, unlimited runs"
    echo "  $0 user/project/abc123 2                  # 2 GPUs per agent, unlimited runs" 
    echo "  $0 user/project/abc123 1 10               # 1 GPU per agent, max 10 runs each"
    echo ""
    echo "🔍 Auto-detect sweep ID from saved files:"
    echo "  $0 auto 1                                 # Use latest sweep ID"
    exit 1
fi

SWEEP_ID="$1"
GPUS_PER_AGENT="${2:-1}"
MAX_RUNS_PER_AGENT="${3:-}"

# Add small rank-based delay to stagger agent startup (reduced since we have separate logs)
RANK_DELAY="${SLURM_PROCID:-0}"
if [ "$RANK_DELAY" -gt 0 ]; then
    echo "⏳ Rank-based delay: ${RANK_DELAY}s (SLURM_PROCID=$RANK_DELAY)"
    sleep "$RANK_DELAY"
fi

# Handle auto-detection of sweep ID
if [ "$SWEEP_ID" = "auto" ]; then
    echo "🔍 Auto-detecting sweep ID from saved files..."
    
    # Try multiple locations in order of preference
    SWEEP_LOCATIONS=(
        "sweep_ids/latest_sweep_id.txt"
        "$HOME/.wandb_sweeps/latest_sweep_id.txt"
        "/tmp/latest_sweep_id.txt"
        "latest_sweep_id.txt"
        "/tmp/sweep_id_${SLURM_JOB_ID}.txt"
    )
    
    DETECTED_SWEEP_ID=""
    for location in "${SWEEP_LOCATIONS[@]}"; do
        if [ -f "$location" ]; then
            DETECTED_SWEEP_ID=$(cat "$location" 2>/dev/null | head -1)
            if [ -n "$DETECTED_SWEEP_ID" ]; then
                echo "✅ Found sweep ID in: $location"
                SWEEP_ID="$DETECTED_SWEEP_ID"
                break
            fi
        fi
    done
    
    if [ -z "$DETECTED_SWEEP_ID" ]; then
        echo "❌ Error: Could not auto-detect sweep ID"
        echo "No sweep ID files found in:"
        for location in "${SWEEP_LOCATIONS[@]}"; do
            echo "  - $location"
        done
        echo ""
        echo "Please provide sweep ID manually."
        exit 1
    fi
fi

# Validate sweep ID format
if ! [[ "$SWEEP_ID" =~ ^[^/]+/[^/]+/[^/]+$ ]]; then
    echo "❌ Error: Invalid sweep ID format"
    echo "Expected format: entity/project/sweep_id"
    echo "Got: $SWEEP_ID"
    exit 1
fi

# Validate gpus_per_agent parameter
if ! [[ "$GPUS_PER_AGENT" =~ ^[0-9]+$ ]] || [ "$GPUS_PER_AGENT" -lt 1 ]; then
    echo "❌ Error: gpus_per_agent must be a positive integer, got: $GPUS_PER_AGENT"
    exit 1
fi

echo "✅ Sweep ID: $SWEEP_ID"
echo "✅ GPUs per agent: $GPUS_PER_AGENT"
if [ -n "$MAX_RUNS_PER_AGENT" ]; then
    echo "✅ Max runs per agent: $MAX_RUNS_PER_AGENT"
else
    echo "✅ Max runs per agent: unlimited"
fi

# Check W&B authentication
echo ""
echo "Checking W&B authentication..."
if ! command -v wandb >/dev/null 2>&1; then
    echo "❌ Error: wandb command not found. Please ensure the conda environment is properly activated."
    echo "Current PATH: $PATH"
    exit 1
fi

if ! wandb status > /dev/null 2>&1; then
    echo "Setting up W&B authentication..."
    if [ -n "$WANDB_API_KEY" ]; then
        echo "Using WANDB_API_KEY from environment"
        wandb login --relogin "$WANDB_API_KEY"
    elif [ -f ~/.wandb_api_key ]; then
        echo "Using API key from ~/.wandb_api_key file"  
        wandb login --relogin "$(cat ~/.wandb_api_key)"
    else
        echo "❌ Error: No W&B API key found!"
        echo "Please either:"
        echo "  1. Set WANDB_API_KEY environment variable"
        echo "  2. Create ~/.wandb_api_key file with your API key"
        echo "  3. Get your API key from: https://wandb.ai/settings"
        exit 1
    fi
else
    echo "✅ W&B authentication OK"
fi

# All nodes perform identical agent startup logic
echo ""
echo "🖥️  Starting agents on current node: ${SLURMD_NODENAME:-$(hostname)} (Rank ${SLURM_PROCID:-0})"
echo "========================================"

# Detect GPUs available on this node
if [ -n "$CUDA_VISIBLE_DEVICES" ]; then
    if [ "$CUDA_VISIBLE_DEVICES" = "" ]; then
        NUM_GPUS=0
    else
        NUM_GPUS=$(echo "$CUDA_VISIBLE_DEVICES" | tr ',' '\n' | wc -l)
    fi
    echo "🔧 CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
    echo "🔧 Number of visible GPUs: $NUM_GPUS"
else
    if command -v nvidia-smi >/dev/null 2>&1; then
        NUM_GPUS=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
        echo "🔧 Detected GPUs via nvidia-smi: $NUM_GPUS"
    else
        echo "⚠️  nvidia-smi not available, defaulting to CPU execution"
        NUM_GPUS=0
    fi
fi

# Calculate number of agents for this node
if [ "$NUM_GPUS" -eq 0 ]; then
    # For CPU mode, spawn multiple agents based on available CPU cores
    NUM_CPU_CORES=$(nproc)
    NUM_AGENTS=$((NUM_CPU_CORES / 4))  # 4 cores per agent for reasonable performance
    if [ "$NUM_AGENTS" -lt 1 ]; then
        NUM_AGENTS=1
    fi
    echo "🔧 No GPUs detected, running $NUM_AGENTS CPU agents (using $NUM_CPU_CORES cores)"
elif [ "$NUM_GPUS" -lt "$GPUS_PER_AGENT" ]; then
    echo "⚠️  Only $NUM_GPUS GPUs available, but $GPUS_PER_AGENT GPUs requested per agent"
    echo "🔧 Running 1 agent with all available GPUs ($NUM_GPUS)"
    NUM_AGENTS=1
else
    NUM_AGENTS=$((NUM_GPUS / GPUS_PER_AGENT))
    echo "🔧 $NUM_GPUS GPUs detected, running $NUM_AGENTS agents with $GPUS_PER_AGENT GPU(s) each"
    
    LEFTOVER_GPUS=$((NUM_GPUS % GPUS_PER_AGENT))
    if [ "$LEFTOVER_GPUS" -gt 0 ]; then
        echo "📝 Note: $LEFTOVER_GPUS GPU(s) will remain unused"
    fi
fi

# Start agents on this node
echo ""
echo "🚀 Starting $NUM_AGENTS agents on node ${SLURMD_NODENAME:-$(hostname)} (Rank ${SLURM_PROCID:-0})..."

for i in $(seq 1 $NUM_AGENTS); do
    if [ "$NUM_GPUS" -gt 0 ]; then
        # Calculate GPU assignment for this agent
        START_GPU=$(((i - 1) * GPUS_PER_AGENT))
        END_GPU=$((START_GPU + GPUS_PER_AGENT - 1))
        
        if [ -n "$CUDA_VISIBLE_DEVICES" ]; then
            # Parse available GPUs from SLURM allocation
            IFS=',' read -ra AVAILABLE_GPUS <<< "$CUDA_VISIBLE_DEVICES"
            
            GPU_LIST=""
            for gpu_idx in $(seq $START_GPU $END_GPU); do
                if [ "$gpu_idx" -lt "${#AVAILABLE_GPUS[@]}" ]; then
                    gpu_id="${AVAILABLE_GPUS[$gpu_idx]}"
                    if [ -z "$GPU_LIST" ]; then
                        GPU_LIST="$gpu_id"
                    else
                        GPU_LIST="$GPU_LIST,$gpu_id"
                    fi
                fi
            done
        else
            # Direct GPU indices
            GPU_LIST=""
            for gpu in $(seq $START_GPU $END_GPU); do
                if [ -z "$GPU_LIST" ]; then
                    GPU_LIST="$gpu"
                else
                    GPU_LIST="$GPU_LIST,$gpu"
                fi
            done
        fi
        
        echo "  🎯 Agent $i: GPU(s) $GPU_LIST"
        
        # Start agent with proper GPU assignment
        if [ -n "$MAX_RUNS_PER_AGENT" ]; then
            CUDA_VISIBLE_DEVICES=$GPU_LIST wandb agent --project conditional-flow-matching --count "$MAX_RUNS_PER_AGENT" "$SWEEP_ID" &
        else
            CUDA_VISIBLE_DEVICES=$GPU_LIST wandb agent --project conditional-flow-matching "$SWEEP_ID" &
        fi
    else
        # CPU execution
        echo "  🎯 Agent $i: CPU mode"
        
        if [ -n "$MAX_RUNS_PER_AGENT" ]; then
            wandb agent --project conditional-flow-matching --count "$MAX_RUNS_PER_AGENT" "$SWEEP_ID" &
        else
            wandb agent --project conditional-flow-matching "$SWEEP_ID" &
        fi
    fi
    
    # Small delay between agent starts
    sleep 1
done

echo ""
echo "✅ All agents started on node ${SLURMD_NODENAME:-$(hostname)} (Rank ${SLURM_PROCID:-0})"

# Display execution summary
echo ""
echo "========================================"
echo "Execution Summary"
echo "========================================"
echo "🆔 Sweep ID: $SWEEP_ID"
echo "🖥️  Current node: ${SLURMD_NODENAME:-$(hostname)}"
echo "👥 Agents on this node: $NUM_AGENTS"
echo "🔧 GPUs per agent: $GPUS_PER_AGENT"
if [ -n "$MAX_RUNS_PER_AGENT" ]; then
    echo "🔄 Max runs per agent: $MAX_RUNS_PER_AGENT"
fi

if [ -n "$SLURM_NNODES" ] && [ "$SLURM_NNODES" -gt 1 ]; then
    echo "🌐 Multi-node execution: Each of the $SLURM_NNODES nodes runs agents independently"
    echo "📊 Total cluster agents: $NUM_AGENTS × $SLURM_NNODES = $((NUM_AGENTS * SLURM_NNODES)) (estimated)"
else
    echo "🖥️  Single-node execution: All agents on current node"
fi

echo ""
echo "🔗 Monitor sweep progress:"
echo "   https://wandb.ai/conditional-flow-matching/sweeps/${SWEEP_ID##*/}"
echo ""

# Wait for all agents on this node to complete
echo "⏳ Waiting for agents to complete on node ${SLURMD_NODENAME:-$(hostname)} (Rank ${SLURM_PROCID:-0})..."
wait

echo ""
echo "========================================"
echo "Node Execution Complete - Rank ${SLURM_PROCID:-0}"
echo "========================================"
echo "✅ All agents completed on node ${SLURMD_NODENAME:-$(hostname)} (Rank ${SLURM_PROCID:-0})"

if [ -n "$SLURM_NNODES" ] && [ "$SLURM_NNODES" -gt 1 ]; then
    echo "📝 Note: Other nodes in the job may still be running agents"
    echo "🌐 Total job has $SLURM_NNODES nodes running in parallel"
fi

echo "🆔 Sweep ID: $SWEEP_ID"
echo "🔗 View results: https://wandb.ai/conditional-flow-matching/sweeps/${SWEEP_ID##*/}"
