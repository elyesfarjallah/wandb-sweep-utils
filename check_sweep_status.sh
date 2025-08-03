#!/bin/bash

# W&B Sweep Status Checker
# Shows status of current sweeps and running jobs
# Usage: ./check_sweep_status.sh [sweep_id]

SWEEP_ID="${1:-auto}"

echo "========================================"
echo "W&B Sweep Status Checker"
echo "========================================"

# Auto-detect sweep ID if needed
if [ "$SWEEP_ID" = "auto" ]; then
    echo "🔍 Auto-detecting sweep ID..."
    
    SWEEP_LOCATIONS=(
        "$HOME/.wandb_sweeps/latest_sweep_id.txt"
        "/tmp/latest_sweep_id.txt"
        "latest_sweep_id.txt"
    )
    
    for location in "${SWEEP_LOCATIONS[@]}"; do
        if [ -f "$location" ]; then
            SWEEP_ID=$(cat "$location" 2>/dev/null | head -1)
            if [ -n "$SWEEP_ID" ]; then
                echo "✅ Found sweep ID in: $location"
                break
            fi
        fi
    done
    
    if [ -z "$SWEEP_ID" ] || [ "$SWEEP_ID" = "auto" ]; then
        echo "❌ No sweep ID found"
        echo ""
        echo "Available sweep files:"
        for location in "${SWEEP_LOCATIONS[@]}"; do
            if [ -f "$location" ]; then
                echo "  ✓ $location: $(cat "$location" 2>/dev/null)"
            else
                echo "  ✗ $location: not found"
            fi
        done
        exit 1
    fi
fi

echo "Current sweep: $SWEEP_ID"
echo ""

# Check SLURM jobs
echo "🔍 SLURM Jobs Status:"
echo "===================="
RUNNING_JOBS=$(squeue -u $(whoami) --noheader 2>/dev/null | wc -l)
if [ "$RUNNING_JOBS" -gt 0 ]; then
    echo "Running jobs for user $(whoami):"
    squeue -u $(whoami) -o "%.10i %.20j %.8T %.10M %.6D %.20R %.8q" 2>/dev/null || echo "Unable to check SLURM status"
else
    echo "No running jobs found for user $(whoami)"
fi

echo ""

# Check for sweep-related processes
echo "🔍 Sweep-related Processes:"
echo "=========================="
SWEEP_PROCESSES=$(ps aux | grep "wandb agent" | grep -v grep || echo "")
if [ -n "$SWEEP_PROCESSES" ]; then
    echo "Active wandb agents:"
    echo "$SWEEP_PROCESSES"
else
    echo "No active wandb agents found"
fi

echo ""

# Show recent sweep files
echo "📁 Recent Sweep Files:"
echo "====================="
if [ -d "$HOME/.wandb_sweeps" ]; then
    echo "Saved sweep IDs (most recent first):"
    ls -lat "$HOME/.wandb_sweeps"/*.txt 2>/dev/null | head -5 | while read line; do
        file=$(echo "$line" | awk '{print $NF}')
        sweep=$(cat "$file" 2>/dev/null)
        echo "  $(basename "$file"): $sweep"
    done
else
    echo "No sweep directory found"
fi

echo ""

# Show W&B status
echo "🌐 W&B Status:"
echo "============="
if command -v wandb >/dev/null 2>&1; then
    if wandb status >/dev/null 2>&1; then
        echo "✅ W&B authentication: OK"
        wandb status 2>/dev/null | grep -E "(Logged in|Current project)" || echo "W&B status check failed"
    else
        echo "❌ W&B authentication: Failed"
    fi
else
    echo "❌ wandb command not available"
fi

echo ""
echo "🔗 Sweep URLs:"
echo "============="
echo "Current sweep: https://wandb.ai/flow-matching/sweeps/${SWEEP_ID##*/}"
echo "All sweeps: https://wandb.ai/flow-matching/sweeps"

echo ""
echo "🚀 Quick Actions:"
echo "================"
echo "Submit more workers:"
echo "  ./submit_sweep_workers.sh $SWEEP_ID [gpus] [duration] [gpus_per_agent]"
echo ""
echo "Submit 6-GPU worker:"
echo "  ./submit_sweep_workers.sh $SWEEP_ID 6 04:00:00 1"
echo ""
echo "Check logs:"
echo "  tail -f logs/slurm_*.out"
