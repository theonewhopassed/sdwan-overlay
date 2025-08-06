use clap::Parser;
use underlay_manager::server::UnderlayManagerServer;
use underlay_manager::config::Config;
use tracing::{info, error};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Configuration file path
    #[arg(short, long, default_value = "config/underlay.yml")]
    config: String,

    /// Log level
    #[arg(short, long, default_value = "info")]
    log_level: String,

    /// gRPC server port
    #[arg(long, default_value = "9093")]
    port: u16,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(&args.log_level)
        .init();

    info!("Starting SD-WAN Underlay Manager");

    // Load configuration
    let config = Config::from_file(&args.config)?;
    info!("Loaded configuration from {}", args.config);

    // Create and start the gRPC server
    let server = UnderlayManagerServer::new(config).await?;
    info!("Underlay manager server initialized on port {}", args.port);

    // Start the server
    if let Err(e) = server.run(args.port).await {
        error!("Server error: {}", e);
        return Err(e.into());
    }

    Ok(())
} 