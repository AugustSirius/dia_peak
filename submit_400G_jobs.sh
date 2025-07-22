#!/bin/bash

# Submit all 400G multi-CPU timstof jobs to HPC

HPC_BASE="/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak"

echo "Submitting 400G Multi-CPU TimsTOF jobs..."
echo "========================================"
echo ""

# Submit 4-CPU versions
for cores in 2 4 8 16 32; do
    dir="timstof_400G_4cpu_${cores}c"
    echo "Submitting $dir..."
    cd "$HPC_BASE/$dir"
    sbatch Rust_run.sh
    sleep 1
done

echo ""

# Submit 8-CPU versions
for cores in 1 2 4 8 16 32; do
    dir="timstof_400G_8cpu_${cores}c"
    echo "Submitting $dir..."
    cd "$HPC_BASE/$dir"
    sbatch Rust_run.sh
    sleep 1
done

echo ""
echo "All 400G jobs submitted!"
echo "Use 'squeue -u $USER' to check status"