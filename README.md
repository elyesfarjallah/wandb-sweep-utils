# W&B Sweep Management Utilities

A comprehensive toolkit for managing Weights & Biases hyperparameter sweeps in distributed computing environments. These scripts provide automated sweep agent management, status monitoring, and lifecycle control for efficient hyperparameter optimization.

## 🚀 Features

- **Distributed Agent Management**: Unified approach for multi-node sweep execution
- **Auto-Detection**: Intelligent sweep ID discovery and validation
- **GPU-Aware Allocation**: Automatic GPU detection and assignment
- **Lifecycle Control**: Complete sweep management (pause/resume/stop/cancel)
- **Real-time Monitoring**: Status tracking and progress visualization
- **SLURM Integration**: Seamless integration with cluster environments

## 📦 Scripts Overview


Below is a detailed description of each script, its arguments, and what it does/returns:

---

### `run_sweep_agent.sh`
**Purpose:** Launches one or more W&B sweep agents on the current node, with support for distributed and SLURM environments.

**Arguments:**
- `<sweep_id>`: The sweep ID (or 'auto' to auto-detect from file)
- `[gpus_per_agent]` (optional): Number of GPUs to allocate per agent (default: 1)
- `[max_runs_per_agent]` (optional): Maximum runs per agent (default: unlimited)

**Behavior:**
- Joins the specified sweep and runs agents, one per SLURM task or process
- Auto-detects sweep ID if 'auto' is given and a sweep ID file is present
- Sets up rank isolation for independent logging
- Returns: Exit code 0 on success, nonzero on error

---

### `manage_sweep.sh`
**Purpose:** Manage the lifecycle of a W&B sweep (pause, resume, stop, cancel, or status).

**Arguments:**
- `<action>`: One of `pause`, `resume`, `stop`, `cancel`, or `status`
- `<sweep_id>`: The sweep ID (or 'auto' to auto-detect from file)

**Behavior:**
- Performs the requested action on the sweep using the W&B API
- Auto-detects sweep ID if 'auto' is given and a sweep ID file is present
- Returns: Prints result/status to stdout, exit code 0 on success

---

### `check_sweep_status.sh`
**Purpose:** Show the status of a W&B sweep, including agent and run progress.

**Arguments:**
- `[sweep_id]` (optional): The sweep ID (or 'auto' to auto-detect from file; default: 'auto')

**Behavior:**
- Prints sweep status, agent status, and progress to stdout
- Auto-detects sweep ID if 'auto' is given and a sweep ID file is present
- Returns: Prints status, exit code 0 on success

---

### `check_sweep_exists.py`
**Purpose:** Python utility to check if a given W&B sweep exists (by querying the W&B API).

**Arguments:**
- Accepts a sweep ID as a command-line argument (or via stdin)

**Behavior:**
- Returns exit code 0 if the sweep exists, 1 if not, and prints a message to stdout
- Can be used in scripts to validate sweep IDs before launching agents or jobs

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/elyesfarjallah/wandb-sweep-utils.git
cd wandb-sweep-utils

# Make scripts executable
chmod +x *.sh

# Start sweep agents with auto-detection
./run_sweep_agent.sh auto 1 10

# Monitor sweep progress
./check_sweep_status.sh auto

# Manage sweep lifecycle
./manage_sweep.sh pause auto
```

## 📋 Prerequisites

- **W&B Account** with API access configured
- **Python 3.7+** with wandb package installed
- **Bash 4.0+** for advanced script features
- **SLURM cluster access** (optional, for distributed execution)
- **GPU access** (optional, for GPU-accelerated training)

## 🔧 Setup

1. **Install W&B**: `pip install wandb`
2. **Login to W&B**: `wandb login`
3. **Configure environment**: Ensure proper Python and CUDA setup
4. **Make scripts executable**: `chmod +x *.sh`

## 📚 Documentation

Each script includes comprehensive help documentation:

```bash
./run_sweep_agent.sh --help
./manage_sweep.sh --help
./check_sweep_status.sh --help
```

## 🔄 Typical Workflow

1. **Create a sweep** in W&B dashboard or via API
2. **Start agents** using `run_sweep_agent.sh`
3. **Monitor progress** with `check_sweep_status.sh`
4. **Manage lifecycle** using `manage_sweep.sh`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 📄 License

This project is licensed under the MIT License.

## 👤 Author

This project is maintained by [Elyes Farjallah](https://github.com/elyesfarjallah).
