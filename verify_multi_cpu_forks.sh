#!/bin/bash

echo "Verifying all multi-CPU forks..."
echo "================================"
echo ""

# Check each multi-CPU fork
for cores in 1 4 8 16 32; do
    folder="timstof_2cpu_${cores}c"
    echo "Checking $folder:"
    
    if [ -d "$folder" ]; then
        echo "  ✓ Directory exists"
        
        # Check config.toml
        if [ -f "$folder/config.toml" ]; then
            echo "  ✓ config.toml found:"
            grep -E "num_cpus|cores_per_cpu" "$folder/config.toml" | grep -v "#" | head -2 | sed 's/^/    /'
        else
            echo "  ✗ config.toml missing!"
        fi
        
        # Check Rust_run.sh
        if [ -f "$folder/Rust_run.sh" ]; then
            echo "  ✓ Rust_run.sh found"
            # Check SLURM parameters
            echo "    SLURM parameters:"
            grep -E "^#SBATCH -[cn]" "$folder/Rust_run.sh" | sed 's/^/      /'
        else
            echo "  ✗ Rust_run.sh missing!"
        fi
        
        # Check essential source files
        if [ -f "$folder/src/multi_cpu.rs" ]; then
            echo "  ✓ src/multi_cpu.rs found"
        else
            echo "  ✗ src/multi_cpu.rs missing!"
        fi
    else
        echo "  ✗ Directory not found!"
    fi
    echo ""
done

# List all timstof directories
echo "All timstof directories:"
echo "========================"
ls -d timstof* | sort | while read dir; do
    if [[ "$dir" == timstof_single_cpu_* ]]; then
        threads=$(echo "$dir" | sed 's/timstof_single_cpu_//')
        echo "$dir - Single CPU with $threads threads"
    elif [[ "$dir" == timstof_2cpu_* ]]; then
        cores=$(echo "$dir" | sed 's/timstof_2cpu_\(.*\)c/\1/')
        total=$((2 * cores))
        echo "$dir - 2 CPUs × $cores cores = $total threads"
    elif [[ "$dir" == "timstof_multi_cpu" ]]; then
        echo "$dir - Original multi-CPU version (2 CPUs × 8 cores = 16 threads)"
    elif [[ "$dir" == "timstof" ]]; then
        echo "$dir - Original single-CPU version"
    fi
done