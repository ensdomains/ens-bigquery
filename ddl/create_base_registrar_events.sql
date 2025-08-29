-- Create raw and decoded BaseRegistrarImplementation event tables
-- This extracts events directly from crypto_ethereum.logs for better data coverage
-- Event signatures are computed using ens-manager.token.get_topic_hash function

-- Set event signature variables
DECLARE name_migrated_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameMigrated(uint256 indexed id, address indexed owner, uint256 expires)');
DECLARE name_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(uint256 indexed id, address indexed owner, uint256 expires)');
DECLARE name_renewed_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRenewed(uint256 indexed id, uint256 expires)');

-- Create raw BaseRegistrarImplementation events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens._raw_base_registrar_events` AS
SELECT 
    block_timestamp,
    block_number, 
    transaction_hash,
    log_index,
    address,
    topics,
    data
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address = '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85'  -- BaseRegistrar (correct address from YAML)
  AND topics[SAFE_OFFSET(0)] IN (
    name_migrated_sig,   -- NameMigrated
    name_registered_sig, -- NameRegistered  
    name_renewed_sig     -- NameRenewed
  );


-- Create decoded NameMigrated events table using ens-manager.token.decode_log
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_base_registrar_NameMigrated` AS
WITH decoded_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data,
    -- Decode using ens-manager's decode_log function
    `ens-manager.token.decode_log`(
      'NameMigrated(uint256 indexed id, address indexed owner, uint256 expires)',
      data,
      topics
    ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_base_registrar_events`
  WHERE topics[SAFE_OFFSET(0)] = name_migrated_sig  -- NameMigrated
)
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Extract fields from topics and decoded data
    topics[SAFE_OFFSET(1)] AS id,           -- uint256 id (indexed)
    topics[SAFE_OFFSET(2)] AS owner,        -- address owner (indexed)
    SAFE_CAST(decoded_data[SAFE_OFFSET(2)] AS INT64) AS expires,  -- uint256 expires
    topics[SAFE_OFFSET(1)] AS labelhash     -- Use id as labelhash
FROM decoded_events;

-- Create decoded NameRegistered events table using ens-manager.token.decode_log
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_base_registrar_NameRegistered` AS
WITH decoded_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data,
    -- Decode using ens-manager's decode_log function
    `ens-manager.token.decode_log`(
      'NameRegistered(uint256 indexed id, address indexed owner, uint256 expires)',
      data,
      topics
    ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_base_registrar_events`
  WHERE topics[SAFE_OFFSET(0)] = name_registered_sig  -- NameRegistered
)
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Extract fields from topics and decoded data
    topics[SAFE_OFFSET(1)] AS id,           -- uint256 id (indexed)
    topics[SAFE_OFFSET(2)] AS owner,        -- address owner (indexed)
    SAFE_CAST(decoded_data[SAFE_OFFSET(2)] AS INT64) AS expires,  -- uint256 expires
    topics[SAFE_OFFSET(1)] AS labelhash     -- Use id as labelhash
FROM decoded_events;

-- Create decoded NameRenewed events table using ens-manager.token.decode_log
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_base_registrar_NameRenewed` AS
WITH decoded_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data,
    -- Decode using ens-manager's decode_log function
    `ens-manager.token.decode_log`(
      'NameRenewed(uint256 indexed id, uint256 expires)',
      data,
      topics
    ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_base_registrar_events`
  WHERE topics[SAFE_OFFSET(0)] = name_renewed_sig   -- NameRenewed
)
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Extract fields from topics and decoded data
    topics[SAFE_OFFSET(1)] AS id,           -- uint256 id (indexed)
    SAFE_CAST(decoded_data[SAFE_OFFSET(1)] AS INT64) AS expires,  -- uint256 expires
    topics[SAFE_OFFSET(1)] AS labelhash     -- Use id as labelhash
FROM decoded_events;