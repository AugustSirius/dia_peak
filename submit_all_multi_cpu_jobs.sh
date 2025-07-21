#!/bin/bash

# This script submits all multi-CPU timstof jobs to HPC

HPC_BASE="/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak"

echo "Submitting all Multi-CPU TimsTOF jobs to HPC..."
echo "=============================================="
echo ""

# Submit all 2-CPU versions with different core counts
for cores in 1 4 8 16 32; do
    dir="timstof_2cpu_${cores}c"
    total_threads=$((2 * cores))
    echo "Submitting $dir (2 CPUs × $cores cores = $total_threads threads)..."
    cd "$HPC_BASE/$dir"
    sbatch Rust_run.sh
    sleep 1  # Small delay between submissions
done

echo ""
echo "All multi-CPU jobs submitted!"
echo ""
echo "To check job status, use: squeue -u $USER"
echo "To see detailed job info: sacct -j <job_id> --format=JobID,JobName,Partition,AllocCPUS,State,ExitCode,Elapsed"
