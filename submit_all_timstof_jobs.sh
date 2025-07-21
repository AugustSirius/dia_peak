#!/bin/bash

# Master script to submit ALL timstof jobs (single-CPU and multi-CPU versions)

HPC_BASE="/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak"

echo "========================================"
echo "Submitting ALL TimsTOF jobs to HPC"
echo "========================================"
echo ""

# Counter for total jobs
total_jobs=0

# Submit single CPU versions
echo "=== Single CPU Versions ==="
for threads in 2 8 16 32 64; do
    dir="timstof_single_cpu_$threads"
    echo "Submitting $dir (1 CPU, $threads threads)..."
    cd "$HPC_BASE/$dir"
    sbatch Rust_run.sh
    ((total_jobs++))
    sleep 1
done
echo ""

# Submit multi-CPU versions (2 CPUs with varying cores)
echo "=== Multi-CPU Versions (2 CPUs) ==="
for cores in 1 4 8 16 32; do
    dir="timstof_2cpu_${cores}c"
    total_threads=$((2 * cores))
    echo "Submitting $dir (2 CPUs × $cores cores = $total_threads threads)..."
    cd "$HPC_BASE/$dir"
    sbatch Rust_run.sh
    ((total_jobs++))
    sleep 1
done
echo ""

# Submit original multi-CPU version
echo "=== Original Multi-CPU Version ==="
echo "Submitting timstof_multi_cpu (2 CPUs × 8 cores = 16 threads)..."
cd "$HPC_BASE/timstof_multi_cpu"
sbatch Rust_run.sh
((total_jobs++))

echo ""
echo "========================================"
echo "Total jobs submitted: $total_jobs"
echo "========================================"
echo ""
echo "To monitor jobs:"
echo "  - Check status: squeue -u \$USER"
echo "  - View details: sacct -j <job_id> --format=JobID,JobName,Partition,AllocCPUS,State,ExitCode,Elapsed"
echo "  - Cancel all: scancel -u \$USER"
echo ""
echo "Job summary:"
echo "  - 5 single-CPU versions (2, 8, 16, 32, 64 threads)"
echo "  - 5 multi-CPU versions with 2 CPUs (1, 4, 8, 16, 32 cores each)"
echo "  - 1 original multi-CPU version (2 CPUs × 8 cores)"