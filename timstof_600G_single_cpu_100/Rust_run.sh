#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_100t
#SBATCH -c 1
#SBATCH -n 80
#SBATCH --mem 500G

echo "=== Running timstof_600G_single_cpu_100 with 100 threads on 1 CPU ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo ""

# Load modules
module load gcc

# Copy dependencies from original timstof if needed
if [ ! -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_600G_single_cpu_100/target" ] && [ -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/target" ]; then
    echo "Copying dependencies from original timstof..."
    cp -r "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/target" "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_600G_single_cpu_100/"
    cp -r "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/Cargo.lock" "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_600G_single_cpu_100/" 2>/dev/null || true
fi

# Change to project directory
cd /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_600G_single_cpu_100

# Verify configuration
echo "Checking configuration..."
grep "parallel_threads" src/main.rs | head -1

# Run with release profile
echo ""
echo "Starting Rust program..."
time cargo run --release

echo ""
echo "Job completed at: $(date)"
