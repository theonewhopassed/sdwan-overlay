use clap::Parser;
use packet_scheduler::scheduler::PacketScheduler;
use packet_scheduler::config::Config;
use tracing::{info, error};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Configuration file path
    #[arg(short, long, default_value = "config/scheduler.yml")]
    config: String,

    /// Log level
    #[arg(short, long, default_value = "info")]
    log_level: String,

    /// Underlay manager endpoint
    #[arg(long, default_value = "http://localhost:9093")]
    underlay_endpoint: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(&args.log_level)
        .init();

    info!("Starting SD-WAN Packet Scheduler");

    // Load configuration
    let config = Config::from_file(&args.config)?;
    info!("Loaded configuration from {}", args.config);

    // Create packet scheduler
    let mut scheduler = PacketScheduler::new(config, args.underlay_endpoint).await?;
    info!("Packet scheduler initialized");

    // Start the scheduler
    if let Err(e) = scheduler.run().await {
        error!("Scheduler error: {}", e);
        return Err(e.into());
    }

    Ok(())
} 