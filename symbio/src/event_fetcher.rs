use anyhow::Result;
use ethers::{
    prelude::*,
    types::{Address, Filter, Log, U64},
    providers::{Provider, Http},
};
use std::{
    str::FromStr, sync::Arc, time::Duration
};

// Import the ABI from abi.rs
use crate::abi::SymbioticRestaking;

pub struct EventFetcher {
    provider: Arc<Provider<Http>>,
    contract_address: Address,
}

impl EventFetcher {
    pub fn new(rpc_url: &str, contract_address: Address) -> Result<Self> {
        let provider = Provider::<Http>::try_from(rpc_url)?;
        Ok(Self {
            provider: Arc::new(provider),
            contract_address,
        })
    }

    pub async fn start_continuous_fetching(&self) -> Result<()> {
        let mut last_processed_block: U64 = 0.into();
        println!("start_continuous_fetching");
            

        loop {

            println!("before_block");
            let latest_block = self.get_latest_block().await?;
            println!("latest_block {}", latest_block);
            

            if last_processed_block >= latest_block {
                last_processed_block = 0.into();
            }

            println!("Fetching events from block {} to {}", last_processed_block, latest_block);
            
            match self.fetch_events(last_processed_block, latest_block).await {
                Ok(logs) => {
                    if !logs.is_empty() {
                        println!("Found {} events", logs.len());
                        self.parse_events(logs.clone())?;
                        
                        if let Some(last_log_block) = logs.last()
                            .and_then(|log| log.block_number) {
                            last_processed_block = last_log_block + 1;
                        }
                    }
                }
                Err(e) => {
                    eprintln!("Error fetching events: {}", e);
                }
            }

            tokio::time::sleep(Duration::from_secs(15)).await;
        }
    }

    async fn get_latest_block(&self) -> Result<U64> {
        
        Ok(self.provider.get_block_number().await?)
    }

    async fn fetch_events(&self, from_block: U64, to_block: U64) -> Result<Vec<Log>> {
        let filter = Filter::new()
            .address(self.contract_address)
            .from_block(from_block)
            .to_block(to_block);

        let logs = self.provider.get_logs(&filter).await?;
        Ok(logs)
    }

    fn parse_events(&self, logs: Vec<Log>) -> Result<()> {
        for log in logs {
            // Parse different event types based on their signatures
            match log.topics.get(0) {
                Some(topic) if *topic == H256::from_str("0x4c0d38aee67a1c4f289d6fad5233bdf3aaab0c9210f9b0a2b34dfc985391f85f").unwrap() => {
                    // Initialized event
                    if let Some(version) = log.data.0.get(0..32) {
                        let version = U256::from_big_endian(version);
                        println!("Initialized Event [Block {}] - Version: {}", 
                            log.block_number.unwrap_or_default(), version);
                    }
                },
                Some(topic) if *topic == H256::from_str("0x9b8daf0171ca11e541d32f15d01c8a1bdc9083077171e9ec7ad54a9a443b1b0b").unwrap() => {
                    // OperatorRegistered event
                    if log.topics.len() >= 2 {
                        let operator = Address::from_slice(&log.topics[1][12..]);
                        let rpc = String::from_utf8_lossy(&log.data).to_string();
                        println!("Operator Registered [Block {}] - Operator: {}, RPC: {}", 
                            log.block_number.unwrap_or_default(), operator, rpc);
                    }
                },
                Some(topic) if *topic == H256::from_str("0x8be0079c531659141344cd1fd0a4f28419497f467f1fda6e65ad5af9e6e87866").unwrap() => {
                    // OwnershipTransferred event
                    if log.topics.len() >= 3 {
                        let previous_owner = Address::from_slice(&log.topics[1][12..]);
                        let new_owner = Address::from_slice(&log.topics[2][12..]);
                        println!("Ownership Transferred [Block {}] - Previous: {}, New: {}", 
                            log.block_number.unwrap_or_default(), previous_owner, new_owner);
                    }
                },
                Some(topic) if *topic == H256::from_str("0xa0e60b6345d8eb0a6b27e5d48f6c9b90a93a9f2040b0945b9e42c17a94b2dca").unwrap() => {
                    // TransactionVerified event
                    // if log.topics.len() >= 4 {
                    //     let validator_pubkey = String::from_utf8_lossy(&log.topics[1]).to_string();
                    //     let block_number = U256::from_big_endian(&log.topics[2][0..32]);
                    //     let tx_id = H256::from_slice(&log.topics[3]);
                    //     println!("Transaction Verified [Block {}] - Validator: {}, Block: {}, TxId: {}", 
                    //         log.block_number.unwrap_or_default(), validator_pubkey, block_number, tx_id);
                    // }
                },
                Some(topic) if *topic == H256::from_str("0xbc7cd55cc527470d01e64a6c44a38d3d3cc6a3b05f74a7b4d80a7d3a94c269e4").unwrap() => {
                    // Upgraded event
                    if log.topics.len() >= 2 {
                        let implementation = Address::from_slice(&log.topics[1][12..]);
                        println!("Contract Upgraded [Block {}] - New Implementation: {}", 
                            log.block_number.unwrap_or_default(), implementation);
                    }
                },
                _ => {
                    println!("Unknown event [Block {}] - Raw log: {:?}", 
                        log.block_number.unwrap_or_default(), log);
                }
            }
        }
        Ok(())
    }
}