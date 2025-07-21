#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_multi
#SBATCH -c 2
#SBATCH -n 8
#SBATCH --mem 200G

echo "=== Running timstof_multi_cpu with 2 CPUs x 8 cores ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo ""

# Load modules
module load gcc

# Copy dependencies from original timstof if needed
if [ ! -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu/target" ] && [ -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/target" ]; then
    echo "Copying dependencies from original timstof..."
    cp -r /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/target /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu/
    cp -r /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof/Cargo.lock /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu/ 2>/dev/null || true
fi

# Change to project directory
cd /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu

# Run with release profile
echo "Starting Rust program..."
time cargo run --release

echo ""
echo "Job completed at: $(date)"
