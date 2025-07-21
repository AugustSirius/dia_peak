#!/bin/bash

# Base directories
LOCAL_BASE="/Users/augustsirius/Desktop/dia_peak"
HPC_BASE="/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak"

# Array of core counts to create
CORE_COUNTS=(1 4 8 16 32)

echo "Creating timstof_multi_cpu forks with 2 CPUs and varying core counts..."
echo "======================================================================"
echo ""

for cores in "${CORE_COUNTS[@]}"; do
    folder_name="timstof_2cpu_${cores}c"
    echo "Creating $folder_name (2 CPUs × $cores cores = $((2 * cores)) total threads)..."
    
    # Copy the multi_cpu folder
    cp -r "$LOCAL_BASE/timstof_multi_cpu" "$LOCAL_BASE/$folder_name"
    
    # Update config.toml
    cat > "$LOCAL_BASE/$folder_name/config.toml" << EOF
# Multi-CPU Configuration File
# Configuration: 2 CPUs × $cores cores per CPU = $((2 * cores)) total threads

[cpu]
# Number of CPUs (SLURM -c parameter)
num_cpus = 2

# Cores per CPU (SLURM -n parameter)
# Total worker threads = num_cpus × cores_per_cpu = 2 × $cores = $((2 * cores))
cores_per_cpu = $cores

# Enable NUMA-aware processing
enable_numa = true

[processing]
# Maximum number of precursors to process
max_precursors = 8000

# Fragment repeat number
frag_repeat_num = 5

# Output directory for results
output_dir = "output_precursors"

[performance]
# Enable performance monitoring
monitor_cpu_usage = true

# Print progress every N precursors
progress_interval = 100

# Work queue buffer size (0 = unbounded)
queue_buffer_size = 0
EOF

    # Create Rust_run.sh
    cat > "$LOCAL_BASE/$folder_name/Rust_run.sh" << EOF
#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_2c${cores}t
#SBATCH -c 2
#SBATCH -n $cores
#SBATCH --mem 200G

echo "=== Running $folder_name with 2 CPUs × $cores cores = $((2 * cores)) threads ==="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURM_NODELIST"
echo "CPUs per task: \$SLURM_CPUS_PER_TASK"
echo "Number of tasks: \$SLURM_NTASKS"
echo ""

# Load modules
module load gcc

# Set environment variables
export RAYON_NUM_THREADS=\$SLURM_CPUS_PER_TASK
export OMP_NUM_THREADS=\$SLURM_CPUS_PER_TASK

# Copy dependencies from original timstof if needed
if [ ! -d "$HPC_BASE/$folder_name/target" ] && [ -d "$HPC_BASE/timstof/target" ]; then
    echo "Copying dependencies from original timstof..."
    cp -r "$HPC_BASE/timstof/target" "$HPC_BASE/$folder_name/"
    cp -r "$HPC_BASE/timstof/Cargo.lock" "$HPC_BASE/$folder_name/" 2>/dev/null || true
fi

# Change to project directory
cd $HPC_BASE/$folder_name

# Verify configuration
echo "Configuration from config.toml:"
grep -E "num_cpus|cores_per_cpu" config.toml | grep -v "#" | head -2
echo ""

# Run with release profile
echo "Starting Rust program..."
time cargo run --release

echo ""
echo "Job completed at: \$(date)"
EOF

    chmod +x "$LOCAL_BASE/$folder_name/Rust_run.sh"
    echo "✓ Created $folder_name"
    echo ""
done

# Create a batch submission script for all multi-CPU versions
cat > "$LOCAL_BASE/submit_all_multi_cpu_jobs.sh" << 'EOF'
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
EOF

chmod +x "$LOCAL_BASE/submit_all_multi_cpu_jobs.sh"

echo "========================================"
echo "Summary of created forks:"
echo ""
for cores in "${CORE_COUNTS[@]}"; do
    echo "✓ timstof_2cpu_${cores}c: 2 CPUs × $cores cores = $((2 * cores)) total threads"
done
echo ""
echo "All multi-CPU forks have been created!"
echo ""
echo "Next steps:"
echo "1. Transfer these folders to HPC"
echo "2. Run submit_all_multi_cpu_jobs.sh to submit all jobs"