#!/bin/bash

echo "Verifying parallel_threads configuration in each fork..."
echo "=================================================="
echo ""

# Check each single CPU fork
for threads in 2 8 16 32 64; do
    folder="timstof_single_cpu_$threads"
    echo "Checking $folder:"
    grep "parallel_threads" "$folder/src/main.rs" | grep "=" | head -1
    echo ""
done

# Check multi_cpu version
echo "Checking timstof_multi_cpu:"
if [ -f "timstof_multi_cpu/config.toml" ]; then
    echo "config.toml found:"
    grep -E "num_cpus|cores_per_cpu" timstof_multi_cpu/config.toml | grep -v "#" | head -2
else
    echo "No config.toml found (uses hardcoded values)"
fi
echo ""

# Check for missing files
echo "Checking for potential missing files..."
echo "======================================"
for dir in timstof_single_cpu_* timstof_multi_cpu; do
    echo ""
    echo "Checking $dir:"
    
    # Check for essential files
    for file in "Cargo.toml" "src/main.rs" "src/utils.rs" "src/processing.rs" "src/cache.rs" "Rust_run.sh"; do
        if [ ! -f "$dir/$file" ]; then
            echo "  ⚠️  MISSING: $file"
        else
            echo "  ✓ Found: $file"
        fi
    done
    
    # Check if it's multi_cpu and needs the multi_cpu.rs file
    if [[ "$dir" == "timstof_multi_cpu" ]]; then
        if [ ! -f "$dir/src/multi_cpu.rs" ]; then
            echo "  ⚠️  MISSING: src/multi_cpu.rs (required for multi-CPU version)"
        else
            echo "  ✓ Found: src/multi_cpu.rs"
        fi
    fi
done

echo ""
echo "Verification complete!"