#!/bin/bash

# This script submits all timstof jobs to HPC

HPC_BASE="/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak"

echo "Submitting all TimsTOF jobs to HPC..."
echo "===================================="
echo ""

# Submit single CPU versions
for threads in 2 8 16 32 64; do
    dir="timstof_single_cpu_$threads"
    echo "Submitting $dir (1 CPU, $threads threads)..."
    cd "$HPC_BASE/$dir"
    sbatch Rust_run.sh
    sleep 1  # Small delay between submissions
done

# Submit multi-CPU version
echo "Submitting timstof_multi_cpu (2 CPUs, 8 cores each)..."
cd "$HPC_BASE/timstof_multi_cpu"
sbatch Rust_run.sh

echo ""
echo "All jobs submitted!"
echo ""
echo "To check job status, use: squeue -u \$USER"
echo "To see detailed job info: sacct -j <job_id> --format=JobID,JobName,Partition,AllocCPUS,State,ExitCode,Elapsed"