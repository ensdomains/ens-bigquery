-- Create all ENS raw event tables by extracting from Ethereum logs
-- Each table filters events by contract addresses for different ENS event types

-- 1. ENS Registry events (current and legacy)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._raw_registry_events` AS
SELECT 
    block_hash,
    block_number,
    block_timestamp,
    transaction_hash,
    transaction_index,
    log_index,
    address,
    data,
    topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
    -- Current ENS Registry
    '0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e',
    -- Legacy ENS Registry  
    '0x314159265dd8dbb310642f98f50c066173c1259b'
)
AND block_timestamp >= '2017-05-04'  -- ENS launch date
ORDER BY block_number, log_index;

-- 2. PublicResolver events (all versions)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._raw_resolver_events` AS
SELECT 
    block_hash,
    block_number,
    block_timestamp,
    transaction_hash,
    transaction_index,
    log_index,
    address,
    data,
    topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
    -- PublicResolver contract addresses (all versions)
    '0xf29100983e058b709f3d539b0c765937b804ac15',
    '0xa2c122be93b0074270ebee7f6b7292c7deb45047',
    '0x5fbb459c49bb06083c33109fa4f14810ec2cf358',
    '0x226159d592e2b063810a10ebf6dcbada94ed68b8',
    '0x4976fb03c32e5b8cfe2b6ccb31c09ba78ebaba41',
    '0xdaaf96c344f63131acadd0ea35170e7892d3dfba',
    '0x231b0ee14048e9dccd1d247744d114a4eb5e8e63',
    '0x5ffc014343cd971b7eb70732021e26c35b744cc4',
    '0x1da022710df5002339274aadee8d58218e9d6ab5',
    '0xd3ddccdd3b25a8a7423b5bee360a42146eb4baf3'
)
AND block_timestamp >= '2017-05-04'  -- ENS launch date
ORDER BY block_number, log_index;

-- 3. BaseRegistrar events
CREATE OR REPLACE TABLE `web3-publicgoods.ens._raw_registrar_events` AS
SELECT 
    block_hash,
    block_number,
    block_timestamp,
    transaction_hash,
    transaction_index,
    log_index,
    address,
    data,
    topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
    -- ENS BaseRegistrar contract
    '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85'
)
AND block_timestamp >= '2019-05-04'  -- BaseRegistrar deployment date
ORDER BY block_number, log_index;

-- 4. EthRegistrarController events (all versions)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._raw_controller_events` AS
SELECT 
    block_hash,
    block_number,
    block_timestamp,
    transaction_hash,
    transaction_index,
    log_index,
    address,
    data,
    topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
    -- EthRegistrarController contracts (all versions)
    '0xf0ad5cad05e10572efceb849f6ff0c68f9700455',  -- Controller v1
    '0xb22c1c159d12461ea124b0deb4b5b93020e6ad16',  -- Controller v2
    '0x283af0b28c62c092c9727f1ee09c02ca627eb7f5',  -- Controller v3
    '0x253553366da8546fc250f225fe3d25d0c782303b',   -- Controller v4
    '0x59e16fccd424cc24e280be16e11bcd56fb0ce547'   -- Controller v5 (current)
)
AND block_timestamp >= '2019-05-04'  -- Controller deployment date
ORDER BY block_number, log_index;

-- 5. NameWrapper events
CREATE OR REPLACE TABLE `web3-publicgoods.ens._raw_name_wrapper_events` AS
SELECT 
    block_hash,
    block_number,
    block_timestamp,
    transaction_hash,
    transaction_index,
    log_index,
    address,
    data,
    topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
    -- ENS NameWrapper contract
    '0xd4416b13d2b3a9abae7acd5797e58e1aaf138218'
)
AND block_timestamp >= '2022-09-14'  -- NameWrapper deployment date
ORDER BY block_number, log_index;