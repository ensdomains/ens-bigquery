-- Create decoded registry event tables following the same pattern as resolver events
-- Decodes NewOwner, Transfer, and NewResolver events from raw registry events

-- ======================
-- REGISTRY EVENTS DECODING  
-- ======================

-- NewOwner Event: event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_registry_NewOwner` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS node,           -- bytes32 indexed
    topics[SAFE_OFFSET(2)] AS label,          -- bytes32 indexed (labelHash)
    CONCAT('0x', SUBSTR(data, 27, 40)) AS owner  -- address from data
FROM `web3-publicgoods.ens.raw_registry_events`
WHERE topics[SAFE_OFFSET(0)] = '0xce0457fe73731f824cc272376169235128c118b49d344817417c6d108d155e82';

-- Transfer Event: event Transfer(bytes32 indexed node, address owner)  
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_registry_Transfer` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS node,           -- bytes32 indexed
    CONCAT('0x', SUBSTR(data, 27, 40)) AS owner  -- address from data
FROM `web3-publicgoods.ens.raw_registry_events`
WHERE topics[SAFE_OFFSET(0)] = '0xd4735d920b0f87494915f556dd9b54c8f309026070caea5c737245152564d266';

-- NewResolver Event: event NewResolver(bytes32 indexed node, address resolver)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_registry_NewResolver` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS node,           -- bytes32 indexed
    CONCAT('0x', SUBSTR(data, 27, 40)) AS resolver  -- address from data
FROM `web3-publicgoods.ens.raw_registry_events`
WHERE topics[SAFE_OFFSET(0)] = '0x335721b01866dc23fbee8b6b2c7b1e14d6f05c28cd35a2c934239f94095602a0';