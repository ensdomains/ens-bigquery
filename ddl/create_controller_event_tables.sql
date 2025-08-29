-- Create decoded controller event tables
-- Phase 1: Decode NameRegistered and NameRenewed events from ALL controller versions
-- Handles Controller v1-v3 (single cost field) and Controller v4 (separate baseCost/premium fields)

-- Uses ens-manager.token.decode_log function for proper Unicode support


-- Create decoded NameRegistered events table using ens-manager.token.decode_log
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_controller_NameRegistered` AS
WITH decoded_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data,
    -- Decode using ens-manager's decode_log function with version-specific ABIs
    CASE 
      WHEN topics[SAFE_OFFSET(0)] = '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27' THEN  -- Controller v4
        `ens-manager.token.decode_log`(
          'NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires)',
          data,
          topics
        )
      ELSE  -- Controller v1-v3  
        `ens-manager.token.decode_log`(
          'NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 cost, uint256 expires)',
          data,
          topics
        )
    END AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] IN (
      '0xb3d987963d01b2f68493b4bdb130988f157ea43070d4ad840fee0466ed9370d9', -- NameRegistered v1
      '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27', -- NameRegistered v4 (new signature)
      '0xca6abbe9d7f11422cb6ca7629fbf6fe9efb1c621f71ce8f02b9f2a230097404f'  -- NameRegistered v1-v3
  )
)
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Extract fields from decoded data array
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    topics[SAFE_OFFSET(2)] AS owner,     -- address owner (indexed) 
    decoded_data[SAFE_OFFSET(0)] AS name, -- string name (decoded with full Unicode support)
    -- Handle cost calculation based on controller version
    CASE 
        WHEN topics[SAFE_OFFSET(0)] = '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27' THEN  -- Controller v4
            SAFE_ADD(
                SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64),  -- baseCost
                SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64)   -- + premium
            )
        ELSE  -- Controller v1-v3
            SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64)      -- cost (total)
    END AS cost,
    -- Extract baseCost (only for Controller v4)
    CASE 
        WHEN topics[SAFE_OFFSET(0)] = '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27' THEN  -- Controller v4
            SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64)      -- baseCost
        ELSE NULL
    END AS base_cost,
    -- Extract premium (only for Controller v4)
    CASE 
        WHEN topics[SAFE_OFFSET(0)] = '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27' THEN  -- Controller v4
            SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64)      -- premium
        ELSE NULL
    END AS premium,
    -- Extract expires field
    CASE 
        WHEN topics[SAFE_OFFSET(0)] = '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27' THEN  -- Controller v4
            SAFE_CAST(decoded_data[SAFE_OFFSET(5)] AS INT64)      -- expires
        ELSE  -- Controller v1-v3
            SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64)      -- expires
    END AS expires
FROM decoded_events;

-- Create decoded NameRenewed events table using ens-manager.token.decode_log
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_controller_NameRenewed` AS  
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
    -- NameRenewed ABI is consistent across all controller versions
    `ens-manager.token.decode_log`(
      'NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires)',
      data,
      topics
    ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`  
  WHERE topics[SAFE_OFFSET(0)] = '0x3da24c024582931cfaf8267d8ed24d13a82a8068d5bd337d30ec45cea4e506ae'
)
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Extract fields from decoded data array
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    decoded_data[SAFE_OFFSET(0)] AS name, -- string name (decoded with full Unicode support)
    SAFE_CAST(decoded_data[SAFE_OFFSET(2)] AS INT64) AS cost,    -- cost (total renewal cost)
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64) AS expires, -- expires timestamp
    -- Note: NameRenewed events do NOT have separate base_cost/premium fields
    NULL AS base_cost,
    NULL AS premium
FROM decoded_events;