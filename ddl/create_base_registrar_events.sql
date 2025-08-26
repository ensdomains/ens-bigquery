-- Create raw and decoded BaseRegistrarImplementation event tables
-- This extracts events directly from crypto_ethereum.logs for better data coverage

-- Create raw BaseRegistrarImplementation events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens.raw_base_registrar_events` AS
SELECT 
    block_timestamp,
    block_number, 
    transaction_hash,
    log_index,
    address,
    topics,
    data
FROM `bigquery-public-data.crypto_ethereum.logs`
WHERE address = '0xfac7bea255a6990f749363002136af6556b31e04'  -- BaseRegistrarImplementation
  AND topics[SAFE_OFFSET(0)] IN (
    '0xea3d7e1195a15d2ddcd859b01abd4c6b960fa9f9264e499a70a90c7f0c64b717',  -- NameMigrated
    '0xb3d987963d01b2f68493b4bdb130988f157ea43070d4ad840fee0466ed9370d9',  -- NameRegistered  
    '0x9b87a00e30f1ac65d898f070f8a3488fe60517182d0a2098e1b4b93a54aa9bd6'   -- NameRenewed
  );


-- Create decoded NameMigrated events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_base_registrar_NameMigrated` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Indexed parameters from topics
    topics[SAFE_OFFSET(1)] AS id,           -- uint256 id (indexed) - already in hex
    topics[SAFE_OFFSET(2)] AS owner,        -- address owner (indexed) - already in hex
    -- Non-indexed parameter from data field (expires is last 16 hex chars)
    SAFE_CAST(CONCAT('0x', SUBSTR(data, -16)) AS INT64) AS expires,  -- uint256 expires (in data)
    -- Use the id topic directly as labelhash (it's the keccak256 hash)
    topics[SAFE_OFFSET(1)] AS labelhash
FROM `web3-publicgoods.ens.raw_base_registrar_events`
WHERE topics[SAFE_OFFSET(0)] = '0xea3d7e1195a15d2ddcd859b01abd4c6b960fa9f9264e499a70a90c7f0c64b717'  -- NameMigrated
  AND data IS NOT NULL;

-- Create decoded NameRegistered events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_base_registrar_NameRegistered` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS id,           -- uint256 id (indexed)
    topics[SAFE_OFFSET(2)] AS owner,        -- address owner (indexed)
    SAFE_CAST(CONCAT('0x', SUBSTR(data, -16)) AS INT64) AS expires,  -- uint256 expires (in data)
    topics[SAFE_OFFSET(1)] AS labelhash     -- Use id as labelhash
FROM `web3-publicgoods.ens.raw_base_registrar_events`
WHERE topics[SAFE_OFFSET(0)] = '0xb3d987963d01b2f68493b4bdb130988f157ea43070d4ad840fee0466ed9370d9'  -- NameRegistered
  AND data IS NOT NULL;

-- Create decoded NameRenewed events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_base_registrar_NameRenewed` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS id,           -- uint256 id (indexed)
    SAFE_CAST(CONCAT('0x', SUBSTR(data, -16)) AS INT64) AS expires,  -- uint256 expires (in data)
    topics[SAFE_OFFSET(1)] AS labelhash     -- Use id as labelhash
FROM `web3-publicgoods.ens.raw_base_registrar_events`
WHERE topics[SAFE_OFFSET(0)] = '0x9b87a00e30f1ac65d898f070f8a3488fe60517182d0a2098e1b4b93a54aa9bd6'   -- NameRenewed
  AND data IS NOT NULL;