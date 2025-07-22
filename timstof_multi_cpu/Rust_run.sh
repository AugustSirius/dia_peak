#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust
#SBATCH -c 2
#SBATCH -n 8
#SBATCH --mem 200G

# Load modules
module load gcc

# Change to project directory
cd /storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak/timstof_multi_cpu

# Run with release profile
cargo run --release