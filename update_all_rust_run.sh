#!/bin/bash

# This script updates all Rust_run.sh files for single CPU forks

# Base directories
LOCAL_BASE="/Users/augustsirius/Desktop/dia_peak"
HPC_BASE="/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/dia_peak"
ORIGINAL_TIMSTOF="$HPC_BASE/timstof"

# Function to create Rust_run.sh for single CPU version
create_single_cpu_rust_run() {
    local folder=$1
    local threads=$2
    local output_file="$LOCAL_BASE/$folder/Rust_run.sh"
    
    cat > "$output_file" << EOF
#!/bin/bash
#SBATCH -p amd-ep2,intel-sc3,amd-ep2-short
#SBATCH -q normal
#SBATCH -J rust_${threads}t
#SBATCH -c 1
#SBATCH -n ${threads}
#SBATCH --mem 200G

echo "=== Running $folder with $threads threads on 1 CPU ==="
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURM_NODELIST"
echo ""

# Load modules
module load gcc

# Copy dependencies from original timstof if needed
if [ ! -d "$HPC_BASE/$folder/target" ] && [ -d "$ORIGINAL_TIMSTOF/target" ]; then
    echo "Copying dependencies from original timstof..."
    cp -r "$ORIGINAL_TIMSTOF/target" "$HPC_BASE/$folder/"
    cp -r "$ORIGINAL_TIMSTOF/Cargo.lock" "$HPC_BASE/$folder/" 2>/dev/null || true
fi

# Change to project directory
cd $HPC_BASE/$folder

# Verify configuration
echo "Checking configuration..."
grep "parallel_threads" src/main.rs | head -1

# Run with release profile
echo ""
echo "Starting Rust program..."
time cargo run --release

echo ""
echo "Job completed at: \$(date)"
EOF

    chmod +x "$output_file"
    echo "Created $output_file"
}

# Update each single CPU fork
echo "Updating Rust_run.sh files for all single CPU forks..."
echo ""

create_single_cpu_rust_run "timstof_single_cpu_2" "2"
create_single_cpu_rust_run "timstof_single_cpu_8" "8"
create_single_cpu_rust_run "timstof_single_cpu_16" "16"
create_single_cpu_rust_run "timstof_single_cpu_32" "32"
create_single_cpu_rust_run "timstof_single_cpu_64" "64"

# Special handling for multi_cpu version
echo ""
echo "Updating multi_cpu version..."
cat > "$LOCAL_BASE/timstof_multi_cpu/Rust_run.sh" << 'EOF'
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
EOF

chmod +x "$LOCAL_BASE/timstof_multi_cpu/Rust_run.sh"
echo "Created $LOCAL_BASE/timstof_multi_cpu/Rust_run.sh"

echo ""
echo "All Rust_run.sh files have been updated!"
echo ""
echo "To submit all jobs at once on HPC, you can use:"
echo "cd $HPC_BASE"
echo "for dir in timstof_single_cpu_*; do cd \$dir && sbatch Rust_run.sh && cd ..; done"
echo "cd timstof_multi_cpu && sbatch Rust_run.sh && cd .."