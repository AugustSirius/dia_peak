# CLAUDE.md - Multi-CPU Version

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Multi-CPU fork** of the Rust project (`read_bruker_data`) for processing TimsTOF mass spectrometry data from Bruker instruments. This version is optimized for HPC environments with multiple CPUs and NUMA architecture support.

## Key Differences from Original

### Multi-CPU Architecture
- **Distributed Processing**: Work is distributed across multiple worker threads
- **CPU Affinity**: Each worker thread is pinned to specific cores
- **NUMA Awareness**: Optimized for Non-Uniform Memory Access architectures
- **Configurable**: CPU count and total cores are adjustable parameters

### SLURM Parameter Mapping
**IMPORTANT**: Understanding of SLURM parameters:
- `-c` (--cpus-per-task): Number of CPUs per task → maps to `num_cpus` in config
- `-n` (--ntasks): Total number of cores/worker threads → maps to `cores_per_cpu` in config
- `--ntasks-per-node`: Should equal `-n` to ensure all tasks run on the same node

Example for 2 CPUs with 8 cores total:
```bash
#SBATCH -c 2    # 2 CPUs per task
#SBATCH -n 8    # 8 total cores (worker threads)
#SBATCH --ntasks-per-node=8  # All 8 tasks on same node
```

### Configuration
```rust
// In config.toml - adjust these values based on your HPC configuration
[cpu]
num_cpus = 2         # Number of CPUs (SLURM -c parameter)
cores_per_cpu = 8    # Total cores (SLURM -n parameter)
enable_numa = true   # Enable NUMA-aware processing
```

## Build and Development Commands

### Building the Project
```bash
# Standard debug build
cargo build

# Fast development build with optimizations
cargo build --profile=dev-opt

# Fast release build (recommended for testing)
cargo build --profile=fast-release

# Standard release build
cargo build --release

# Maximum performance build (for production/benchmarks)
cargo build --profile=max-perf
```

### Running the Application
```bash
# Run with debug build
cargo run

# Run with release build
cargo run --release

# Run with specific profile
cargo run --profile=fast-release

# Cache management commands
cargo run -- --clear-cache    # Clear all cached data
cargo run -- --cache-info     # Display cache information
```

### Development Tools
```bash
# Format code
cargo fmt

# Run linter
cargo clippy

# Check for compilation errors without building
cargo check
```

## Architecture and Code Structure

### Main Components

1. **Multi-CPU Module** (timstof/src/multi_cpu.rs):
   - `MultiCpuConfig`: Configuration structure for CPU/core settings
   - `MultiCpuProcessor`: Handles work distribution across worker threads
   - CPU affinity management for optimal cache usage
   - Per-CPU statistics tracking

2. **Data Processing Pipeline** (timstof/src/):
   - `main.rs`: Entry point with multi-CPU configuration
   - `utils.rs`: Core utilities for reading TimsTOF data
   - `processing.rs`: Processing algorithms
   - `cache.rs`: Caching system for processed data

3. **Key Features**:
   - Work queue distribution using crossbeam channels
   - Worker threads distributed across CPUs
   - Automatic CPU affinity binding when supported
   - Real-time progress tracking per worker

### Dependencies and Features

- **core_affinity**: CPU affinity management for optimal performance
- **crossbeam**: Lock-free concurrent data structures for work distribution
- **num_cpus**: Automatic CPU detection
- **rayon**: Parallel processing within each worker
- **timsrust**: Core library for reading Bruker TimsTOF data
- **polars**: DataFrame operations
- **ndarray**: N-dimensional array operations

### Performance Considerations

#### Multi-CPU Configuration
- Set `num_cpus` to match SLURM's `-c` parameter (CPUs per task)
- Set `cores_per_cpu` to match SLURM's `-n` parameter (total cores)
- Total computational capacity = num_cpus × cores_per_cpu
- Enable `enable_numa` for NUMA-aware systems

#### Work Distribution
- Precursors are distributed across worker threads using a work queue
- Each worker thread can utilize multiple CPUs
- CPU affinity ensures optimal memory locality
- Load balancing happens automatically through the work queue

#### Memory Optimization
- NUMA-aware allocation when enabled
- Minimized cross-CPU communication
- Shared read-only data (MS1, finder) uses Arc for efficiency

## SLURM Integration

Example SLURM script for multi-CPU execution:
```bash
#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_multi_cpu
#SBATCH -c 2     # CPUs per task (matches num_cpus)
#SBATCH -n 8     # Total cores (matches cores_per_cpu)
#SBATCH --mem 200G
#SBATCH --ntasks-per-node=8  # Ensure all tasks on same node

# Load modules
module load gcc

# Set environment variables for optimal performance
export RAYON_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Run the multi-CPU version
cd /path/to/timstof_multi_cpu
cargo run --profile=max-perf
```

## Important Notes

- **Shared Memory Required**: All tasks must have access to shared memory (same node)
- **NUMA Awareness**: Performance is best on NUMA systems with proper CPU affinity
- **Configuration**: Always match the code configuration to SLURM parameters
- **Monitoring**: Worker and CPU utilization statistics are printed at the end
- The project processes large datasets - ensure adequate memory
- Cache files are stored in a `.cache` directory (ignored by git)