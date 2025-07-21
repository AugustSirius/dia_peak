#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_multi_cpu
#SBATCH -c 2              # Number of CPUs (adjust to match num_cpus in config.toml)
#SBATCH -n 8              # Total cores (adjust to match cores_per_cpu in config.toml)
#SBATCH --mem 200G
#SBATCH --ntasks-per-node=8  # All tasks on same node for shared memory
#SBATCH --exclusive          # Get exclusive access to nodes for consistent performance

########################## Multi-CPU Rust Run #####################

# Load required modules
module load gcc

# Set environment variables for optimal performance
# Each task (core) can use the available CPUs
export RAYON_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Enable huge pages for better memory performance
export MALLOC_ARENA_MAX=4

# Print configuration information
echo "=== Multi-CPU Configuration ==="
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Number of nodes: $SLURM_JOB_NUM_NODES"
echo "CPUs per task (-c): $SLURM_CPUS_PER_TASK"
echo "Number of tasks/cores (-n): $SLURM_NTASKS"
echo "Total threads: $((SLURM_NTASKS * SLURM_CPUS_PER_TASK))"
echo "Memory limit: $SLURM_MEM_PER_NODE MB"
echo "Node list: $SLURM_JOB_NODELIST"
echo ""
echo "Interpretation:"
echo "  - Running $SLURM_NTASKS worker threads"
echo "  - Each worker can use $SLURM_CPUS_PER_TASK CPUs"
echo "  - Total computational capacity: $((SLURM_NTASKS * SLURM_CPUS_PER_TASK)) CPU-cores"
echo "==============================="

# Change to project directory
cd /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu

# Build with maximum performance profile
echo "Building with max-perf profile..."
cargo build --profile=max-perf

# Run the multi-CPU version
echo "Starting multi-CPU processing..."
time cargo run --profile=max-perf

# Print resource usage summary
echo ""
echo "=== Resource Usage Summary ==="
sacct -j $SLURM_JOB_ID --format=JobID,JobName,Partition,AllocCPUS,Elapsed,MaxRSS,MaxVMSize,State