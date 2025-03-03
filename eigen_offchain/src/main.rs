mod abi;
// mod lib;

use eigen_offchain::EigenLayerClient;
use ethers::prelude::*;

use anyhow::Result;
use clap::{Parser, Subcommand};
use ethers::types::{Address, H256, U256};

use std::{str::FromStr, sync::Arc};

#[derive(Parser)]
#[command(name = "EigenLayer Restaking CLI")]
#[command(version = "1.0")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Get the interface version
    GetInterfaceVersion,
    
    /// Get AVS directory address
    GetAvsDirectory,
    
    
    /// Get whitelisted strategies
    GetWhitelistedStrategies,
    
    /// Get restakeable strategies
    GetRestakeableStrategies,
    
    /// Get provider collateral
    GetProviderCollateral {
        operator: String,
        collateral: String,
    },
    
    /// Get provider collateral tokens
    GetProviderCollateralTokens {
        operator: String,
    },
    
    /// Get operator restaked strategies
    GetOperatorRestakedStrategies {
        operator: String,
    },
    
    /// Get operator stake at a specific timestamp
    GetOperatorStakeAt {
        operator: String,
        collateral: String,
        timestamp: u64,
    },
    
    /// Check if a strategy is enabled
    IsStrategyEnabled {
        strategy: String,
    },
    
    /// Register a strategy
    RegisterStrategy {
        strategy: String,
    },
    
    /// Deregister a strategy
    DeregisterStrategy {
        strategy: String,
    },
    
    /// Register an operator
    RegisterOperator {
        rpc: String,
        rpc1: String,
        rpc2: String,
        signature: String,
        salt: String,
        expiry: String,
    },
    
    /// Register an operator to AVS
    RegisterOperatorToAVS {
        operator: String,
        signature: String,
        salt: String,
        expiry: String,
    },
    
    /// Deregister an operator from AVS
    DeregisterOperatorFromAVS {
        operator: String,
    },
    
    /// Pause strategy
    PauseStrategy,
    
    /// Unpause strategy
    UnpauseStrategy,
    
    /// Update AVS metadata URI
    UpdateAVSMetadataURI {
        metadata_uri: String,
    },
    
    /// Transfer ownership
    TransferOwnership {
        new_owner: String,
    },
    
    /// Initialize the contract
    Initialize {
        owner: String,
        parameters: String,
        avs_directory: String,
        delegation_manager: String,
        strategy_manager: String,
        restaking_helper: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenv::dotenv().ok();

    let cli = Cli::parse();

    let contract_address = dotenv::var("CONTRACT_ADDRESS")?.parse()?;
    let client = EigenLayerClient::new(contract_address)?;

    match cli.command {
        Commands::GetInterfaceVersion => {
            let version = client.get_upgrade_interface_version().await?;
            println!("Interface Version: {}", version);
        }
        
        Commands::GetAvsDirectory => {
            let directory = client.get_avs_directory().await?;
            println!("AVS Directory: {}", directory);
        }
        
        // Commands::GetCurrentPeriod => {
        //     let period = client.get_current_period().await?;
        //     println!("Current Period: {}", period);
        // }
        
        Commands::GetWhitelistedStrategies => {
            let strategies = client.get_whitelisted_strategies().await?;
            println!("Whitelisted Strategies:");
            for (i, strategy) in strategies.iter().enumerate() {
                println!("  {}: {}", i + 1, strategy);
            }
        }
        
        Commands::GetRestakeableStrategies => {
            let strategies = client.get_restakeable_strategies().await?;
            println!("Restakeable Strategies:");
            for (i, strategy) in strategies.iter().enumerate() {
                println!("  {}: {}", i + 1, strategy);
            }
        }
        
        Commands::GetProviderCollateral { operator, collateral } => {
            let amount = client
                .get_provider_collateral(
                    Address::from_str(&operator)?,
                    Address::from_str(&collateral)?,
                )
                .await?;
            println!("Provider Collateral: {}", amount);
        }
        
        Commands::GetProviderCollateralTokens { operator } => {
            let (tokens, amounts) = client
                .get_provider_collateral_tokens(Address::from_str(&operator)?)
                .await?;
            
            println!("Provider Collateral Tokens:");
            for (i, (token, amount)) in tokens.iter().zip(amounts.iter()).enumerate() {
                println!("  {}: {} - {}", i + 1, token, amount);
            }
        }
        
        Commands::GetOperatorRestakedStrategies { operator } => {
            let strategies = client
                .get_operator_restaked_strategies(Address::from_str(&operator)?)
                .await?;
            
            println!("Operator Restaked Strategies:");
            for (i, strategy) in strategies.iter().enumerate() {
                println!("  {}: {}", i + 1, strategy);
            }
        }
        
        Commands::GetOperatorStakeAt { operator, collateral, timestamp } => {
            let amount = client
                .get_operator_stake_at(
                    Address::from_str(&operator)?,
                    Address::from_str(&collateral)?,
                    timestamp,
                )
                .await?;
            println!("Operator Stake: {}", amount);
        }
        
        Commands::IsStrategyEnabled { strategy } => {
            let enabled = client
                .is_strategy_enabled(Address::from_str(&strategy)?)
                .await?;
            println!("Strategy Enabled: {}", enabled);
        }
        
        Commands::RegisterStrategy { strategy } => {
            client
                .register_strategy(Address::from_str(&strategy)?)
                .await?;
            println!("Strategy registered successfully");
        }
        
        Commands::DeregisterStrategy { strategy } => {
            client
                .deregister_strategy(Address::from_str(&strategy)?)
                .await?;
            println!("Strategy deregistered successfully");
        }
        
        Commands::RegisterOperator { rpc, rpc1, rpc2, signature, salt, expiry } => {
            // Parse the signature as hex string
            let signature_bytes = hex::decode(signature.trim_start_matches("0x"))?;
            
            // Parse the salt as 32-byte array
            let salt_bytes = H256::from_str(&salt)?;
            let mut salt_array = [0u8; 32];
            salt_array.copy_from_slice(salt_bytes.as_bytes());
            
            // Parse the expiry as U256
            let expiry_value = U256::from_dec_str(&expiry)?;
            
            client
                .register_operator(rpc, rpc1, rpc2, signature_bytes, salt_array, expiry_value)
                .await?;
            println!("Operator registered successfully");
        }
        
        Commands::RegisterOperatorToAVS { operator, signature, salt, expiry } => {
            // Parse the signature as hex string
            let signature_bytes = hex::decode(signature.trim_start_matches("0x"))?;
            
            // Parse the salt as 32-byte array
            let salt_bytes = H256::from_str(&salt)?;
            let mut salt_array = [0u8; 32];
            salt_array.copy_from_slice(salt_bytes.as_bytes());
            
            // Parse the expiry as U256
            let expiry_value = U256::from_dec_str(&expiry)?;
            
            client
                .register_operator_to_avs(
                    Address::from_str(&operator)?,
                    signature_bytes,
                    salt_array,
                    expiry_value
                )
                .await?;
            println!("Operator registered to AVS successfully");
        }
        
        Commands::DeregisterOperatorFromAVS { operator } => {
            client
                .deregister_operator_from_avs(Address::from_str(&operator)?)
                .await?;
            println!("Operator deregistered from AVS successfully");
        }
        
        Commands::PauseStrategy => {
            client.pause_strategy().await?;
            println!("Strategy paused successfully");
        }
        
        Commands::UnpauseStrategy => {
            client.unpause_strategy().await?;
            println!("Strategy unpaused successfully");
        }
        
        Commands::UpdateAVSMetadataURI { metadata_uri } => {
            client.update_avs_metadata_uri(metadata_uri).await?;
            println!("AVS metadata URI updated successfully");
        }
        
        Commands::TransferOwnership { new_owner } => {
            client
                .transfer_ownership(Address::from_str(&new_owner)?)
                .await?;
            println!("Ownership transferred successfully");
        }
        
        Commands::Initialize { owner, parameters, avs_directory, delegation_manager, strategy_manager, restaking_helper } => {
            client
                .initialize(
                    Address::from_str(&owner)?,
                    Address::from_str(&parameters)?,
                    Address::from_str(&avs_directory)?,
                    Address::from_str(&delegation_manager)?,
                    Address::from_str(&strategy_manager)?,
                    Address::from_str(&restaking_helper)?,
                )
                .await?;
            println!("Contract initialized successfully");
        }
    }

    Ok(())
}