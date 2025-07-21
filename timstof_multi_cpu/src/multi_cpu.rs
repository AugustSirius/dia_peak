use std::sync::{Arc, Mutex, atomic::{AtomicUsize, Ordering}};
use std::thread;
use std::error::Error;
use crossbeam::channel::{unbounded, Sender, Receiver};
use num_cpus;
use core_affinity;
use rayon::prelude::*;
use crate::utils::{IndexedTimsTOFData, PrecursorLibData};
use crate::processing::{FastChunkFinder, process_single_precursor};

#[derive(Clone, Debug)]
pub struct MultiCpuConfig {
    pub num_cpus: usize,      // Number of CPUs (SLURM -c parameter)
    pub cores_per_cpu: usize,  // Cores per CPU (SLURM -n parameter)
    pub enable_numa: bool,
}

impl MultiCpuConfig {
    pub fn total_threads(&self) -> usize {
        self.num_cpus * self.cores_per_cpu
    }
    
    pub fn from_system() -> Self {
        let total_cores = num_cpus::get();
        let physical_cpus = num_cpus::get_physical();
        let cores_per_cpu = total_cores / physical_cpus;
        
        Self {
            num_cpus: physical_cpus,
            cores_per_cpu,
            enable_numa: true,
        }
    }
}

pub struct CpuStats {
    pub utilization: f32,
    pub precursors_processed: usize,
}

pub struct BatchResults {
    pub total_processed: usize,
    pub successful: usize,
    pub failed: usize,
    pub cpu_stats: Option<Vec<CpuStats>>,
}

pub struct MultiCpuProcessor {
    config: MultiCpuConfig,
}

impl MultiCpuProcessor {
    pub fn new(config: MultiCpuConfig) -> Self {
        Self { config }
    }
    
    pub fn process_precursors_distributed(
        &self,
        precursor_lib_data_list: Vec<PrecursorLibData>,
        ms1_indexed: IndexedTimsTOFData,
        finder: FastChunkFinder,
        frag_repeat_num: usize,
        device: &str,
        output_dir: &str,
    ) -> Result<BatchResults, Box<dyn Error>> {
        let ms1_indexed = Arc::new(ms1_indexed);
        let finder = Arc::new(finder);
        let device = device.to_string();
        let output_dir = output_dir.to_string();
        
        // Create channels for work distribution
        let (work_sender, work_receiver): (Sender<Option<PrecursorLibData>>, Receiver<Option<PrecursorLibData>>) = unbounded();
        let work_receiver = Arc::new(Mutex::new(work_receiver));
        
        // Statistics
        let total_processed = Arc::new(AtomicUsize::new(0));
        let successful = Arc::new(AtomicUsize::new(0));
        let failed = Arc::new(AtomicUsize::new(0));
        
        // CPU-specific statistics
        let cpu_stats: Arc<Mutex<Vec<AtomicUsize>>> = Arc::new(Mutex::new(
            (0..self.config.num_cpus)
                .map(|_| AtomicUsize::new(0))
                .collect()
        ));
        
        // Send all work items
        for precursor in precursor_lib_data_list {
            work_sender.send(Some(precursor))?;
        }
        
        // Send termination signals for all workers
        let total_workers = self.config.num_cpus * self.config.cores_per_cpu;
        for _ in 0..total_workers {
            work_sender.send(None)?;
        }
        
        // Create worker threads for each core on each CPU
        let mut handles = vec![];
        
        // We spawn one worker thread per core across all CPUs
        let total_workers = self.config.num_cpus * self.config.cores_per_cpu; // Total threads
        
        for worker_id in 0..total_workers {
            let work_receiver = Arc::clone(&work_receiver);
            let ms1_indexed = Arc::clone(&ms1_indexed);
            let finder = Arc::clone(&finder);
            let total_processed = Arc::clone(&total_processed);
            let successful = Arc::clone(&successful);
            let failed = Arc::clone(&failed);
            let cpu_stats = Arc::clone(&cpu_stats);
            let device = device.clone();
            let output_dir = output_dir.clone();
            let cores_per_cpu = self.config.cores_per_cpu;
            let enable_numa = self.config.enable_numa;
            
            let num_cpus = self.config.num_cpus;
            
            let handle = thread::spawn(move || {
                // Set CPU affinity if supported
                if enable_numa {
                    if let Some(core_ids) = core_affinity::get_core_ids() {
                        // Calculate which CPU this worker should run on
                        let cpu_id = worker_id / cores_per_cpu; // Which CPU
                        let core_within_cpu = worker_id % cores_per_cpu; // Which core on that CPU
                        
                        // Calculate the specific physical core for this worker
                        let target_core = worker_id; // Simple mapping: worker_id maps to core_id
                        
                        if target_core < core_ids.len() {
                            // Set affinity to specific core
                            let _ = core_affinity::set_for_current(core_ids[target_core]);
                            
                            // Each worker runs on a single core with its own rayon pool
                            let pool = rayon::ThreadPoolBuilder::new()
                                .num_threads(num_cpus) // Each worker can use all CPUs
                                .build();
                            
                            if let Ok(pool) = pool {
                                // Process work items within this CPU's thread pool
                                pool.install(|| {
                                    process_cpu_work(
                                        worker_id,
                                        num_cpus,
                                        work_receiver,
                                        &ms1_indexed,
                                        &finder,
                                        frag_repeat_num,
                                        &device,
                                        &output_dir,
                                        &total_processed,
                                        &successful,
                                        &failed,
                                        &cpu_stats,
                                    );
                                });
                            } else {
                                // Fallback to default processing
                                process_cpu_work(
                                    worker_id,
                                    num_cpus,
                                    work_receiver,
                                    &ms1_indexed,
                                    &finder,
                                    frag_repeat_num,
                                    &device,
                                    &output_dir,
                                    &total_processed,
                                    &successful,
                                    &failed,
                                    &cpu_stats,
                                );
                            }
                        }
                    }
                } else {
                    // Process without CPU affinity
                    process_cpu_work(
                        worker_id,
                        num_cpus,
                        work_receiver,
                        &ms1_indexed,
                        &finder,
                        frag_repeat_num,
                        &device,
                        &output_dir,
                        &total_processed,
                        &successful,
                        &failed,
                        &cpu_stats,
                    );
                }
            });
            
            handles.push(handle);
        }
        
        // Wait for all workers to complete
        for handle in handles {
            handle.join().map_err(|_| "Thread panicked")?;
        }
        
        // Collect CPU statistics
        let cpu_stats_final = cpu_stats.lock().unwrap()
            .iter()
            .map(|count| CpuStats {
                utilization: 1.0, // Simplified for now
                precursors_processed: count.load(Ordering::SeqCst),
            })
            .collect();
        
        Ok(BatchResults {
            total_processed: total_processed.load(Ordering::SeqCst),
            successful: successful.load(Ordering::SeqCst),
            failed: failed.load(Ordering::SeqCst),
            cpu_stats: Some(cpu_stats_final),
        })
    }
}

fn process_cpu_work(
    worker_id: usize,
    num_cpus: usize,
    work_receiver: Arc<Mutex<Receiver<Option<PrecursorLibData>>>>,
    ms1_indexed: &IndexedTimsTOFData,
    finder: &FastChunkFinder,
    frag_repeat_num: usize,
    device: &str,
    output_dir: &str,
    total_processed: &AtomicUsize,
    successful: &AtomicUsize,
    failed: &AtomicUsize,
    cpu_stats: &Arc<Mutex<Vec<AtomicUsize>>>,
) {
    // cpu_stats has num_cpus entries, so we can safely use modulo
    let cpu_id = worker_id % num_cpus; // Simple round-robin distribution across CPUs
    loop {
        // Get work item
        let precursor_data = {
            let receiver = work_receiver.lock().unwrap();
            match receiver.recv() {
                Ok(Some(data)) => data,
                Ok(None) => break, // Termination signal
                Err(_) => break,   // Channel closed
            }
        };
        
        // Process the precursor
        let result = process_single_precursor(
            &precursor_data,
            ms1_indexed,
            finder,
            frag_repeat_num,
            device,
            output_dir,
        );
        
        // Update statistics
        let current = total_processed.fetch_add(1, Ordering::SeqCst) + 1;
        cpu_stats.lock().unwrap()[cpu_id].fetch_add(1, Ordering::SeqCst);
        
        match result {
            Ok(_) => {
                successful.fetch_add(1, Ordering::SeqCst);
                println!("[Worker {} (CPU {})][{}/total] ✓ Successfully processed: {}", 
                         worker_id, cpu_id, current, precursor_data.precursor_id);
            },
            Err(e) => {
                failed.fetch_add(1, Ordering::SeqCst);
                eprintln!("[Worker {} (CPU {})][{}/total] ✗ Error processing {}: {}", 
                          worker_id, cpu_id, current, precursor_data.precursor_id, e);
            }
        }
    }
}