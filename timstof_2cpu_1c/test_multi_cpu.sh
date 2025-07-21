#!/bin/bash

echo "=== Multi-CPU Configuration Test ==="
echo ""

# Check CPU information
echo "System CPU Information:"
echo "- Total CPU cores: $(nproc)"
echo "- Physical CPUs: $(lscpu | grep 'Socket(s):' | awk '{print $2}')"
echo "- Cores per socket: $(lscpu | grep 'Core(s) per socket:' | awk '{print $4}')"
echo "- NUMA nodes: $(lscpu | grep 'NUMA node(s):' | awk '{print $3}')"
echo ""

# Check if config.toml exists
if [ -f "config.toml" ]; then
    echo "Configuration file found: config.toml"
    echo "Current settings:"
    grep -E "num_cpus|cores_per_cpu|enable_numa" config.toml | sed 's/^/  /'
else
    echo "WARNING: config.toml not found, will use default settings"
fi
echo ""

# Build test
echo "Testing build..."
if cargo check; then
    echo "✓ Build check passed"
else
    echo "✗ Build check failed"
    exit 1
fi
echo ""

# Test with small configuration
echo "Creating test configuration..."
cat > test_config.toml << EOF
[cpu]
num_cpus = 2
cores_per_cpu = 2
enable_numa = false

[processing]
max_precursors = 10
frag_repeat_num = 5
output_dir = "test_output"

[performance]
monitor_cpu_usage = true
progress_interval = 1
queue_buffer_size = 0
EOF

echo "Test configuration created (2 CPUs × 2 cores = 4 threads)"
echo ""

# Run a quick test if on the correct system
if [ -d "/Users/augustsirius/Desktop/raw_data" ] || [ -d "/storage/guotiannanLab" ]; then
    echo "Test data directory found, running quick test..."
    # Backup original config
    [ -f "config.toml" ] && mv config.toml config.toml.bak
    
    # Use test config
    mv test_config.toml config.toml
    
    echo "Starting test run with minimal configuration..."
    timeout 60s cargo run -- --cache-info
    
    # Restore original config
    rm -f config.toml
    [ -f "config.toml.bak" ] && mv config.toml.bak config.toml
else
    echo "Test data not found, skipping runtime test"
    rm -f test_config.toml
fi

echo ""
echo "=== Test Complete ===