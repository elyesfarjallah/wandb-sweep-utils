#!/bin/bash

# W&B Sweep Management Utility
# Provides commands to pause, resume, stop, or cancel sweeps
# Usage: ./manage_sweep.sh <action> <sweep_id>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <action> <sweep_id>

Manage W&B sweeps with pause, resume, stop, and cancel operations.

Actions:
  pause     Pause a sweep (temporarily stop new runs, keep running ones)
  resume    Resume a paused sweep
  stop      Stop a sweep (finish running runs, no new ones)
  cancel    Cancel a sweep (kill all runs immediately)
  status    Show sweep status and information

Arguments:
  sweep_id  W&B sweep ID (e.g., user/project/sweep_id or 'auto' for latest)

Examples:
  $0 pause user/project/abc123
  $0 resume auto                     # Use latest sweep ID
  $0 stop \$(cat sweep_ids/latest_sweep_id.txt)
  $0 status user/project/abc123

Auto-detection:
  Use 'auto' as sweep_id to automatically detect from saved files:
  - sweep_ids/latest_sweep_id.txt
  - ~/.wandb_sweeps/latest_sweep_id.txt
  - /tmp/latest_sweep_id.txt
EOF
}

# Check for help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    usage
    exit 0
fi

# Get action and sweep ID
ACTION="$1"
SWEEP_ID="${2:-}"

# Validate action
case "$ACTION" in
    pause|resume|stop|cancel|status)
        ;;
    *)
        echo -e "${RED}Error: Invalid action '$ACTION'${NC}" >&2
        echo "Valid actions: pause, resume, stop, cancel, status"
        exit 1
        ;;
esac

# Validate sweep ID
if [ -z "$SWEEP_ID" ]; then
    echo -e "${RED}Error: Sweep ID is required${NC}" >&2
    usage
    exit 1
fi

# Handle auto-detection of sweep ID
if [ "$SWEEP_ID" = "auto" ]; then
    echo -e "${BLUE}🔍 Auto-detecting sweep ID...${NC}"
    
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
                echo -e "${GREEN}✅ Found sweep ID in: $location${NC}"
                SWEEP_ID="$DETECTED_SWEEP_ID"
                break
            fi
        fi
    done
    
    if [ -z "$DETECTED_SWEEP_ID" ]; then
        echo -e "${RED}❌ Error: Could not auto-detect sweep ID${NC}" >&2
        echo "No sweep ID files found in:"
        for location in "${SWEEP_LOCATIONS[@]}"; do
            echo "  - $location"
        done
        exit 1
    fi
fi

# Validate sweep ID format
if ! echo "$SWEEP_ID" | grep -qE '^[^/]+/[^/]+/[^/]+$'; then
    echo -e "${YELLOW}⚠️  Warning: Sweep ID format looks unusual${NC}"
    echo "Expected format: entity/project/sweep_id"
    echo "Got: $SWEEP_ID"
    echo "Proceeding anyway..."
fi

# Check W&B authentication
if ! command -v wandb >/dev/null 2>&1; then
    echo -e "${RED}Error: wandb command not found${NC}" >&2
    exit 1
fi

if ! wandb status >/dev/null 2>&1; then
    echo -e "${RED}Error: Not logged into W&B${NC}" >&2
    echo "Please run: wandb login"
    exit 1
fi

# Extract project and entity from sweep ID
if [[ "$SWEEP_ID" =~ ^([^/]+)/([^/]+)/([^/]+)$ ]]; then
    SWEEP_ENTITY="${BASH_REMATCH[1]}"
    SWEEP_PROJECT="${BASH_REMATCH[2]}"
    SWEEP_SHORT_ID="${BASH_REMATCH[3]}"
    SWEEP_URL="https://wandb.ai/$SWEEP_ENTITY/$SWEEP_PROJECT/sweeps/$SWEEP_SHORT_ID"
else
    SWEEP_ENTITY=""
    SWEEP_PROJECT=""
    SWEEP_SHORT_ID=""
    SWEEP_URL="https://wandb.ai/[entity]/[project]/sweeps/[sweep_id]"
fi

echo "========================================"
echo "W&B Sweep Management"
echo "========================================"
echo "Action: $ACTION"
echo "Sweep ID: $SWEEP_ID"
if [ -n "$SWEEP_ENTITY" ]; then
    echo "Entity: $SWEEP_ENTITY"
    echo "Project: $SWEEP_PROJECT"
    echo "Short ID: $SWEEP_SHORT_ID"
fi
echo "URL: $SWEEP_URL"
echo ""

# Execute the action
case "$ACTION" in
    pause)
        echo -e "${YELLOW}⏸️  Pausing sweep...${NC}"
        echo "This will stop new runs from starting but keep existing runs running."
        if [ -n "$SWEEP_PROJECT" ] && [ -n "$SWEEP_ENTITY" ]; then
            wandb sweep --pause --project "$SWEEP_PROJECT" --entity "$SWEEP_ENTITY" "$SWEEP_ID"
        else
            wandb sweep --pause "$SWEEP_ID"
        fi
        echo -e "${GREEN}✅ Sweep paused successfully${NC}"
        ;;
    resume)
        echo -e "${GREEN}▶️  Resuming sweep...${NC}"
        echo "This will allow new runs to start again."
        if [ -n "$SWEEP_PROJECT" ] && [ -n "$SWEEP_ENTITY" ]; then
            wandb sweep --resume --project "$SWEEP_PROJECT" --entity "$SWEEP_ENTITY" "$SWEEP_ID"
        else
            wandb sweep --resume "$SWEEP_ID"
        fi
        echo -e "${GREEN}✅ Sweep resumed successfully${NC}"
        ;;
    stop)
        echo -e "${BLUE}🛑 Stopping sweep...${NC}"
        echo "This will finish currently running runs and prevent new ones from starting."
        if [ -n "$SWEEP_PROJECT" ] && [ -n "$SWEEP_ENTITY" ]; then
            wandb sweep --stop --project "$SWEEP_PROJECT" --entity "$SWEEP_ENTITY" "$SWEEP_ID"
        else
            wandb sweep --stop "$SWEEP_ID"
        fi
        echo -e "${GREEN}✅ Sweep stopped successfully${NC}"
        ;;
    cancel)
        echo -e "${RED}❌ Cancelling sweep...${NC}"
        echo "This will immediately kill all running runs and prevent new ones."
        echo -e "${YELLOW}⚠️  This action cannot be undone!${NC}"
        read -p "Are you sure you want to cancel the sweep? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -n "$SWEEP_PROJECT" ] && [ -n "$SWEEP_ENTITY" ]; then
                wandb sweep --cancel --project "$SWEEP_PROJECT" --entity "$SWEEP_ENTITY" "$SWEEP_ID"
            else
                wandb sweep --cancel "$SWEEP_ID"
            fi
            echo -e "${RED}✅ Sweep cancelled${NC}"
        else
            echo -e "${BLUE}ℹ️  Cancellation aborted${NC}"
        fi
        ;;
    status)
        echo -e "${BLUE}📊 Checking sweep status...${NC}"
        echo "Sweep URL: $SWEEP_URL"
        echo ""
        echo "Use the W&B web interface to view detailed status information."
        echo "The CLI doesn't provide a direct status command, but you can:"
        echo "  1. Visit the sweep URL above"
        echo "  2. Check running agents with: ps aux | grep 'wandb agent'"
        echo "  3. Monitor SLURM jobs with: squeue -u \$USER"
        ;;
esac

echo ""
echo "========================================"
echo "Management Complete"
echo "========================================"
echo -e "${GREEN}Action '$ACTION' completed for sweep: $SWEEP_ID${NC}"
echo "View sweep: $SWEEP_URL"
