# TimsTOF Multi-CPU Version

This is a multi-CPU fork of the TimsTOF data processing project, designed specifically for HPC environments with multiple CPUs and NUMA architecture.

## Key Features

- **Multi-CPU Distribution**: Distributes work across multiple worker threads
- **NUMA-Aware**: Optimized for Non-Uniform Memory Access architectures
- **CPU Affinity**: Pins threads to specific CPU cores for optimal cache usage
- **Configurable**: Easy configuration through `config.toml` file
- **HPC-Ready**: Designed for SLURM-based HPC clusters

## Understanding SLURM Parameters

**IMPORTANT**: The SLURM parameters map to our configuration as follows:
- `-c` (--cpus-per-task): Number of CPUs each task can use → `num_cpus` in config
- `-n` (--ntasks): Total number of worker threads/cores → `cores_per_cpu` in config
- `--ntasks-per-node`: Should equal `-n` to ensure shared memory access

### Example: 2 CPUs with 8 total cores
```bash
#SBATCH -c 2    # Each task can use 2 CPUs
#SBATCH -n 8    # Run 8 worker threads total
#SBATCH --ntasks-per-node=8  # All 8 on same node
```

This creates 8 worker threads, each able to utilize 2 CPUs, giving you 16 CPU-cores of computational capacity.

## Quick Start

### 1. Configure for Your HPC System

Edit `config.toml` to match your HPC configuration:

```toml
[cpu]
num_cpus = 2         # Number of CPUs per task (SLURM -c)
cores_per_cpu = 8    # Total worker threads (SLURM -n)
enable_numa = true   # Enable NUMA optimization

[processing]
max_precursors = 8000
frag_repeat_num = 5
output_dir = "output_precursors"
```

### 2. Submit SLURM Job

```bash
sbatch Rust_run_multi_cpu.sh
```

Or customize the SLURM script:

```bash
#!/bin/bash
#SBATCH -c 2     # CPUs per task (match config num_cpus)
#SBATCH -n 8     # Total cores (match config cores_per_cpu)
#SBATCH --mem 200G
#SBATCH --ntasks-per-node=8  # Keep all tasks on same node

cd /path/to/timstof_multi_cpu
cargo run --release
```

### 3. Monitor Performance

The program will output:
- Real-time progress per worker thread
- Final statistics showing work distribution
- CPU utilization metrics

## Architecture

### Work Distribution Model

```
Main Thread
    |
    ├── Work Queue (crossbeam channel)
    |
    ├── Worker 0 (can use 2 CPUs)
    ├── Worker 1 (can use 2 CPUs)
    ├── Worker 2 (can use 2 CPUs)
    ├── ... 
    └── Worker 7 (can use 2 CPUs)
    
Total: 8 workers × 2 CPUs = 16 CPU-cores capacity
```

### Key Components

1. **MultiCpuConfig**: Configuration structure
2. **MultiCpuProcessor**: Manages work distribution
3. **Work Queue**: Lock-free queue for distributing precursors
4. **Worker Threads**: Independent workers with CPU access

## Performance Tuning

### CPU Configuration Examples

**Example 1: Many cores, few CPUs per task**
```toml
num_cpus = 2        # 2 CPUs per worker
cores_per_cpu = 16  # 16 worker threads
# Total: 32 CPU-cores capacity
```

**Example 2: Few cores, many CPUs per task**
```toml
num_cpus = 8        # 8 CPUs per worker
cores_per_cpu = 4   # 4 worker threads
# Total: 32 CPU-cores capacity
```

**Example 3: Single-CPU mode (like original)**
```toml
num_cpus = 1        # 1 CPU per worker
cores_per_cpu = 32  # 32 worker threads
# Total: 32 CPU-cores capacity
```

### Memory Considerations
- Each worker processes independently, reducing memory contention
- Shared read-only data (MS1, finder) uses Arc pointers
- Work queue is lock-free for minimal overhead

## Differences from Original

| Feature | Original | Multi-CPU Version |
|---------|----------|-------------------|
| Parallelism | Single rayon pool | Multiple workers with CPU access |
| Work Distribution | rayon par_iter | Work queue + workers |
| CPU Affinity | No | Yes (configurable) |
| Configuration | Hardcoded | config.toml file |
| Progress Tracking | Global counter | Per-worker tracking |

## Troubleshooting

### Performance Issues
1. Check worker distribution: Workers should be evenly loaded
2. Verify SLURM parameters match config.toml
3. Monitor with `htop` to see CPU utilization

### Configuration Mismatch
- Ensure SLURM `-c` matches `num_cpus` in config
- Ensure SLURM `-n` matches `cores_per_cpu` in config
- Check total capacity doesn't exceed available resources

### Memory Issues
- Each worker needs sufficient memory
- Reduce `cores_per_cpu` if running out of memory
- Consider increasing `--mem` in SLURM script

## Building for Maximum Performance

```bash
# Clean build
cargo clean

# Build with maximum optimization
cargo build --profile=max-perf

# Run
cargo run --profile=max-perf
```

## Testing Configuration

To test with a small configuration:

```bash
./test_multi_cpu.sh
```

This will create a test configuration with 2 CPUs × 2 cores and run a quick test.