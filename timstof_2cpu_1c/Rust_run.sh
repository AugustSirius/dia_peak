#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_2c1t
#SBATCH -c 2
#SBATCH -n 1
#SBATCH --mem 200G

echo "=== Running timstof_2cpu_1c with 2 CPUs × 1 cores = 2 threads ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs per task: $SLURM_CPUS_PER_TASK"
echo "Number of tasks: $SLURM_NTASKS"
echo ""

# Load modules
module load gcc

# Set environment variables
export RAYON_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Copy dependencies from original timstof if needed
if [ ! -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_2cpu_1c/target" ] && [ -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/target" ]; then
    echo "Copying dependencies from original timstof..."
    cp -r "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/target" "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_2cpu_1c/"
    cp -r "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/Cargo.lock" "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_2cpu_1c/" 2>/dev/null || true
fi

# Change to project directory
cd /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_2cpu_1c

# Verify configuration
echo "Configuration from config.toml:"
grep -E "num_cpus|cores_per_cpu" config.toml | grep -v "#" | head -2
echo ""

# Run with release profile
echo "Starting Rust program..."
time cargo run --release

echo ""
echo "Job completed at: $(date)"
