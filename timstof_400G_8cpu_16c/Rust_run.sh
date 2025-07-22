#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust
#SBATCH -c 8
#SBATCH -n 16
#SBATCH --mem 400G

# Load modules
module load gcc

# Copy dependencies from original timstof_multi_cpu if needed
if [ ! -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_400G_8cpu_16c/target" ] && [ -d "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu/target" ]; then
    echo "Copying dependencies from original timstof_multi_cpu..."
    cp -r "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu/target" "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_400G_8cpu_16c/"
    cp -r "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu/Cargo.lock" "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_400G_8cpu_16c/" 2>/dev/null || true
fi

# Change to project directory
cd /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_400G_8cpu_16c

# Run with release profile
cargo run --release
