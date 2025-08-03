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

| Script | Purpose | Key Features |
|--------|---------|--------------|
| `run_sweep_agent.sh` | Distributed sweep agent runner | Unified logic, auto-detection, GPU-aware allocation |
| `manage_sweep.sh` | Sweep lifecycle management | Pause/resume/stop/cancel operations |
| `check_sweep_status.sh` | Status monitoring | Real-time progress tracking, agent status |
| `check_sweep_exists.py` | Sweep validation utility | Python-based sweep existence verification |

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
