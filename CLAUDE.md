# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rust project (`read_bruker_data`) for processing TimsTOF mass spectrometry data from Bruker instruments. It focuses on high-performance data processing with parallel computing capabilities.

## Build and Development Commands

### Building the Project
```bash
# Standard debug build
cargo build

# Fast development build with optimizations
cargo build --profile=dev-opt

# Fast release build (recommended for testing)
cargo build --profile=fast-release

# Standard release build
cargo build --release

# Maximum performance build (for production/benchmarks)
cargo build --profile=max-perf
```

### Running the Application
```bash
# Run with debug build
cargo run

# Run with release build
cargo run --release

# Run with specific profile
cargo run --profile=fast-release

# Cache management commands
cargo run -- --clear-cache    # Clear all cached data
cargo run -- --cache-info     # Display cache information
```

### Development Tools
```bash
# Format code
cargo fmt

# Run linter
cargo clippy

# Check for compilation errors without building
cargo check
```

## Architecture and Code Structure

### Main Components

1. **Data Processing Pipeline** (timstof/src/):
   - `main.rs`: Entry point, orchestrates the entire data processing workflow
   - `utils.rs`: Core utilities for reading TimsTOF data, building matrices, and data transformation
   - `processing.rs`: High-performance algorithms for intensity matrix building and feature extraction
   - `cache.rs`: Manages caching of processed data for performance optimization

2. **Key Data Structures**:
   - `LibCols`: Column indices for library data
   - `PrecursorLibData`: Precursor library information
   - Various matrix structures (Array2, Array3, Array4) for efficient numerical operations

3. **Processing Flow**:
   - Reads TimsTOF raw data files
   - Processes library data (parquet format)
   - Builds indexed data structures for fast lookup
   - Extracts MS2 data and builds intensity matrices
   - Performs parallel processing using rayon
   - Caches intermediate results for performance

### Dependencies and Features

- **timsrust**: Core library for reading Bruker TimsTOF data
- **polars**: DataFrame operations and parquet file handling
- **ndarray**: N-dimensional array operations with rayon support
- **rayon**: Parallel processing across CPU cores
- **Cache system**: Uses bincode serialization for fast data persistence

### Performance Considerations

- Configurable parallel processing with `parallel_threads` parameter in main.rs:
  - Set to 1 for sequential processing
  - Set to 2+ for parallel processing with specified thread count
  - Default is set to 4 threads
- Multiple build profiles optimized for different use cases
- Extensive use of parallel iterators and concurrent data structures
- Memory-efficient processing with streaming where possible
- Caching system to avoid recomputing expensive operations

### Parallel Processing Configuration

The `parallel_threads` parameter in main.rs (line 26) controls precursor processing:
```rust
let parallel_threads = 4; // Set to 1 for sequential, 2+ for parallel processing
```
- When set to 1: Processes precursors sequentially in order
- When set to 2+: Processes precursors in parallel using specified thread count
- Progress tracking adapts to the mode (sequential shows step-by-step, parallel shows concurrent progress)

## Important Notes

- No test suite currently exists - consider adding tests when implementing new features
- The project processes large datasets - monitor memory usage during development
- Cache files are stored in a `.cache` directory (ignored by git)
- All file paths in the code assume Unix-style paths