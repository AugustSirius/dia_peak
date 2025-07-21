mod utils;
mod cache;
mod processing;
mod multi_cpu;

use cache::CacheManager;
use utils::{
    read_timstof_data, build_indexed_data, read_parquet_with_polars,
    library_records_to_dataframe, merge_library_and_report, get_unique_precursor_ids, 
    process_library_fast, create_rt_im_dicts, build_lib_matrix, build_precursors_matrix_step1, 
    build_precursors_matrix_step2, build_range_matrix_step3, build_precursors_matrix_step3, 
    build_frag_info, LibCols, PrecursorLibData, prepare_precursor_lib_data
};
use processing::{
    FastChunkFinder, build_intensity_matrix_optimized, prepare_precursor_features,
    calculate_mz_range, extract_ms2_data, build_mask_matrices, extract_aligned_rt_values,
    reshape_and_combine_matrices, create_final_dataframe, process_single_precursor
};
use multi_cpu::{MultiCpuConfig, MultiCpuProcessor};

use rayon::prelude::*;
use std::{error::Error, path::Path, time::Instant, env, fs::File};
use std::fs;
use ndarray::{Array2, Array3, Array4, s, Axis};
use polars::prelude::*;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Config {
    cpu: CpuConfig,
    processing: ProcessingConfig,
    performance: PerformanceConfig,
}

#[derive(Debug, Deserialize)]
struct CpuConfig {
    num_cpus: usize,      // Number of CPUs (SLURM -c parameter)
    cores_per_cpu: usize, // Cores per CPU (SLURM -n parameter)  
    enable_numa: bool,
}

#[derive(Debug, Deserialize)]
struct ProcessingConfig {
    max_precursors: usize,
    frag_repeat_num: usize,
    output_dir: String,
}

#[derive(Debug, Deserialize)]
struct PerformanceConfig {
    monitor_cpu_usage: bool,
    progress_interval: usize,
    queue_buffer_size: usize,
}

fn main() -> Result<(), Box<dyn Error>> {
    // Load configuration from file or use defaults
    let config = load_config()?;
    
    // Multi-CPU configuration from config file
    let cpu_config = MultiCpuConfig {
        num_cpus: config.cpu.num_cpus,         // SLURM -c parameter
        cores_per_cpu: config.cpu.cores_per_cpu, // SLURM -n parameter
        enable_numa: config.cpu.enable_numa,
    };
    
    let total_threads = cpu_config.total_threads();
    println!("Initializing Multi-CPU processing:");
    println!("  - Number of CPUs (SLURM -c): {}", cpu_config.num_cpus);
    println!("  - Cores per CPU (SLURM -n): {}", cpu_config.cores_per_cpu);
    println!("  - Total threads: {}", total_threads);
    println!("  - NUMA-aware: {}", cpu_config.enable_numa);
    
    // Initialize global thread pool with total thread count
    rayon::ThreadPoolBuilder::new()
        .num_threads(total_threads)
        .build_global()
        .unwrap();
    
    let args: Vec<String> = env::args().collect();
    
    // Handle command-line arguments for cache operations
    if let Some(arg) = args.get(1) {
        match arg.as_str() {
            "--clear-cache" => {
                CacheManager::new().clear_cache()?;
                return Ok(());
            }
            "--cache-info" => {
                let cache_manager = CacheManager::new();
                let info = cache_manager.get_cache_info()?;
                if info.is_empty() {
                    println!("Cache is empty");
                } else {
                    println!("Cache files:");
                    for (name, _, size_str) in info {
                        println!("  {} - {}", name, size_str);
                    }
                }
                return Ok(());
            }
            _ => {}
        }
    }
    
    // Automatic OS detection and file path assignment
    let is_macos = std::env::consts::OS == "macos";
    println!("Detected OS: {}", std::env::consts::OS);
    println!("Using macOS paths: {}", is_macos);
    
    // Set file paths based on OS detection
    let (default_data_folder, lib_file_path, report_file_path) = if is_macos {
        // macOS paths
        (
            "/Users/augustsirius/Desktop/raw_data/CAD20220207yuel_TPHP_DIA_pool1_Slot2-54_1_4382.d".to_string(),
            "/Users/augustsirius/Desktop/raw_data/TPHPlib_frag1025_swissprot_final_all_from_Yueliang.tsv",
            "/Users/augustsirius/Desktop/raw_data/report.parquet"
        )
    } else {
        // Non-macOS paths (original paths)
        (
            "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/test_data/CAD20220207yuel_TPHP_DIA_pool1_Slot2-54_1_4382.d".to_string(),
            "/storage/guotiannanLab/wangshuaiyao/777.library/TPHPlib_frag1025_swissprot_final_all_from_Yueliang.tsv",
            "/storage/guotiannanLab/wangshuaiyao/006.DIABERT_TimsTOF_Rust/test_data/report.parquet"
        )
    };
    
    // Set data folder path (can still be overridden by command line argument)
    let d_folder = args.get(1).cloned().unwrap_or(default_data_folder);
    
    let d_path = Path::new(&d_folder);
    if !d_path.exists() {
        return Err(format!("folder {:?} not found", d_path).into());
    }
    
    println!("Using data folder: {}", d_folder);
    println!("Using library file: {}", lib_file_path);
    println!("Using report file: {}", report_file_path);
    
    // ================================ DATA LOADING AND INDEXING ================================
    let cache_manager = CacheManager::new();
    
    println!("\n========== DATA PREPARATION PHASE ==========");
    let total_start = Instant::now();
    
    let (ms1_indexed, ms2_indexed_pairs) = if cache_manager.is_cache_valid(d_path) {
        println!("Found valid cache, loading indexed data directly...");
        let cache_load_start = Instant::now();
        let result = cache_manager.load_indexed_data(d_path)?;
        println!("Cache loading time: {:.5} seconds", cache_load_start.elapsed().as_secs_f32());
        result
    } else {
        println!("Cache invalid or non-existent, reading TimsTOF data...");
        
        // Read raw data
        let raw_data_start = Instant::now();
        let raw_data = read_timstof_data(d_path)?;
        println!("Raw data reading time: {:.5} seconds", raw_data_start.elapsed().as_secs_f32());
        println!("  - MS1 data points: {}", raw_data.ms1_data.mz_values.len());
        println!("  - MS2 windows: {}", raw_data.ms2_windows.len());
        
        // Build indexed data
        println!("\nBuilding indexed data structures...");
        let index_start = Instant::now();
        let (ms1_indexed, ms2_indexed_pairs) = build_indexed_data(raw_data)?;
        println!("Index building time: {:.5} seconds", index_start.elapsed().as_secs_f32());
        
        // Save to cache
        let cache_save_start = Instant::now();
        cache_manager.save_indexed_data(d_path, &ms1_indexed, &ms2_indexed_pairs)?;
        println!("Cache saving time: {:.5} seconds", cache_save_start.elapsed().as_secs_f32());
        
        (ms1_indexed, ms2_indexed_pairs)
    };
    
    println!("Total data preparation time: {:.5} seconds", total_start.elapsed().as_secs_f32());
    
    // Create MS2 finder for fast chunk lookup
    let finder = FastChunkFinder::new(ms2_indexed_pairs)?;
    
    // ================================ LIBRARY AND REPORT LOADING ================================
    println!("\n========== LIBRARY AND REPORT PROCESSING ==========");
    let lib_processing_start = Instant::now();
    
    let library_records = process_library_fast(lib_file_path)?;
    let library_df = library_records_to_dataframe(library_records.clone())?;
    
    let report_df = read_parquet_with_polars(report_file_path)?;
    
    let diann_result = merge_library_and_report(library_df, report_df)?;
    let diann_precursor_id_all = get_unique_precursor_ids(&diann_result)?;
    let (assay_rt_kept_dict, assay_im_kept_dict) = create_rt_im_dicts(&diann_precursor_id_all)?;
    
    println!("Library and report processing time: {:.5} seconds", lib_processing_start.elapsed().as_secs_f32());
    
    // Set processing parameters from config
    let device = "cpu";
    let frag_repeat_num = config.processing.frag_repeat_num;
    
    // ================================ BATCH PRECURSOR PROCESSING ================================
    println!("\n========== BATCH PRECURSOR PROCESSING ==========");
    
    // Step 1: Prepare library data first
    println!("\n[Step 1] Preparing library data for batch processing");
    let prep_start = Instant::now();
    
    // 获取unique precursor IDs
    let unique_precursor_ids: Vec<String> = diann_precursor_id_all
        .column("transition_group_id")?
        .str()?
        .into_iter()
        .filter_map(|opt| opt.map(|s| s.to_string()))
        .collect();
    
    let lib_cols = LibCols::default();
    let max_precursors = config.processing.max_precursors;
    
    // Initialize multi-CPU processor
    let multi_cpu_processor = MultiCpuProcessor::new(cpu_config.clone());
    
    // 预先构建所有precursor的library data
    let precursor_lib_data_list = prepare_precursor_lib_data(
        &library_records,
        &unique_precursor_ids,
        &assay_rt_kept_dict,
        &assay_im_kept_dict,
        &lib_cols,
        max_precursors,
    )?;
    
    println!("  - Prepared data for {} precursors", precursor_lib_data_list.len());
    println!("  - Preparation time: {:.5} seconds", prep_start.elapsed().as_secs_f32());
    
    // 释放library_records的内存，因为我们已经不需要它了
    drop(library_records);
    println!("  - Released library_records from memory");
    
    // Step 2: Process each precursor sequentially (可以后续改为并行)
    println!("\n[Step 2] Processing individual precursors");
    
    // 创建输出目录
    let output_dir = &config.processing.output_dir;
    std::fs::create_dir_all(output_dir)?;

    let batch_start = Instant::now();
    
    // Process precursors using multi-CPU distribution
    println!("\nDistributing work across {} worker threads ({} CPUs × {} cores per CPU)...", 
             cpu_config.cores_per_cpu, cpu_config.num_cpus, cpu_config.cores_per_cpu / cpu_config.num_cpus);
    
    let batch_results = multi_cpu_processor.process_precursors_distributed(
        precursor_lib_data_list,
        ms1_indexed,
        finder,
        frag_repeat_num,
        device,
        output_dir,
    )?;
    
    let batch_elapsed = batch_start.elapsed();
    println!("\n========== MULTI-CPU BATCH PROCESSING SUMMARY ==========");
    println!("Configuration:");
    println!("  - Number of CPUs (SLURM -c): {}", cpu_config.num_cpus);
    println!("  - Total cores (SLURM -n): {}", cpu_config.cores_per_cpu);
    println!("  - Total threads: {}", total_threads);
    println!("  - NUMA-aware: {}", cpu_config.enable_numa);
    println!("\nResults:");
    println!("  - Total precursors processed: {}", batch_results.total_processed);
    println!("  - Successful: {}", batch_results.successful);
    println!("  - Failed: {}", batch_results.failed);
    println!("  - Total batch processing time: {:.5} seconds", batch_elapsed.as_secs_f32());
    println!("  - Average time per precursor: {:.5} seconds", 
             batch_elapsed.as_secs_f32() / batch_results.total_processed as f32);
    
    // Print CPU utilization statistics if available
    if let Some(cpu_stats) = batch_results.cpu_stats {
        println!("\nCPU Utilization:");
        for (cpu_id, stats) in cpu_stats.iter().enumerate() {
            println!("  - CPU {}: {:.1}% utilization, {} precursors processed", 
                     cpu_id, stats.utilization * 100.0, stats.precursors_processed);
        }
    }
    
    Ok(())
}

fn load_config() -> Result<Config, Box<dyn Error>> {
    // Try to load config.toml from current directory
    let config_path = "config.toml";
    
    if Path::new(config_path).exists() {
        let config_str = fs::read_to_string(config_path)?;
        let config: Config = toml::from_str(&config_str)?;
        println!("Loaded configuration from {}", config_path);
        Ok(config)
    } else {
        // Use default configuration
        println!("No config.toml found, using default configuration");
        Ok(Config {
            cpu: CpuConfig {
                num_cpus: 2,      // Default: 2 CPUs (SLURM -c)
                cores_per_cpu: 8, // Default: 8 cores per CPU (SLURM -n)
                enable_numa: true,
            },
            processing: ProcessingConfig {
                max_precursors: 8000,
                frag_repeat_num: 5,
                output_dir: "output_precursors".to_string(),
            },
            performance: PerformanceConfig {
                monitor_cpu_usage: true,
                progress_interval: 100,
                queue_buffer_size: 0,
            },
        })
    }
}
