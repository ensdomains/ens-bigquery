-- Create decoded controller event tables
-- Phase 1: Decode NameRegistered and NameRenewed events from ALL controller versions
-- Handles Controller v1-v3 (single cost field), Controller v4 (separate baseCost/premium fields),
-- and Controller v5 (baseCost/premium/referrer fields)

-- Uses ens-manager.token.decode_log function for proper Unicode support
-- Event signatures are computed using ens-manager.token.get_topic_hash function

-- Set event signature variables
DECLARE controller_v5_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(string label, bytes32 indexed labelhash, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires, bytes32 referrer)');
DECLARE controller_v5_renewed_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRenewed(string label, bytes32 indexed labelhash, uint256 cost, uint256 expires, bytes32 referrer)');
DECLARE controller_v4_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires)');
DECLARE controller_v1_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 cost, uint256 expires)');
DECLARE controller_renewed_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires)');

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
      WHEN topics[SAFE_OFFSET(0)] = controller_v5_registered_sig THEN  -- Controller v5
        `ens-manager.token.decode_log`(
          'NameRegistered(string label, bytes32 indexed labelhash, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires, bytes32 referrer)',
          data,
          topics
        )
      WHEN topics[SAFE_OFFSET(0)] = controller_v4_registered_sig THEN  -- Controller v4
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
      controller_v1_registered_sig,  -- NameRegistered v1-v3 (both use same signature)
      controller_v4_registered_sig,  -- NameRegistered v4 (new signature with baseCost/premium)
      controller_v5_registered_sig   -- NameRegistered v5 (with referrer)
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
    CONCAT('0x', SUBSTR(topics[SAFE_OFFSET(2)], 27)) AS owner,     -- address owner (indexed, extract last 20 bytes)
    decoded_data[SAFE_OFFSET(0)] AS name, -- string name/label (decoded with full Unicode support)
    -- Handle cost calculation based on controller version
    CASE
        WHEN topics[SAFE_OFFSET(0)] IN (controller_v4_registered_sig, controller_v5_registered_sig) THEN  -- Controller v4/v5
            SAFE_ADD(
                SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64),  -- baseCost
                SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64)   -- + premium
            )
        ELSE  -- Controller v1-v3
            SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64)      -- cost (total)
    END AS cost,
    -- Extract baseCost (for Controller v4/v5)
    CASE
        WHEN topics[SAFE_OFFSET(0)] IN (controller_v4_registered_sig, controller_v5_registered_sig) THEN
            SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64)      -- baseCost
        ELSE NULL
    END AS base_cost,
    -- Extract premium (for Controller v4/v5)
    CASE
        WHEN topics[SAFE_OFFSET(0)] IN (controller_v4_registered_sig, controller_v5_registered_sig) THEN
            SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64)      -- premium
        ELSE NULL
    END AS premium,
    -- Extract expires field
    CASE
        WHEN topics[SAFE_OFFSET(0)] IN (controller_v4_registered_sig, controller_v5_registered_sig) THEN
            SAFE_CAST(decoded_data[SAFE_OFFSET(5)] AS INT64)      -- expires
        ELSE  -- Controller v1-v3
            SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64)      -- expires
    END AS expires,
    -- Extract referrer (only for Controller v5)
    CASE
        WHEN topics[SAFE_OFFSET(0)] = controller_v5_registered_sig THEN
            decoded_data[SAFE_OFFSET(6)]                          -- referrer
        ELSE NULL
    END AS referrer
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
    -- Decode using ens-manager's decode_log function with version-specific ABIs
    CASE
      WHEN topics[SAFE_OFFSET(0)] = controller_v5_renewed_sig THEN  -- Controller v5
        `ens-manager.token.decode_log`(
          'NameRenewed(string label, bytes32 indexed labelhash, uint256 cost, uint256 expires, bytes32 referrer)',
          data,
          topics
        )
      ELSE  -- Controller v1-v4
        `ens-manager.token.decode_log`(
          'NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires)',
          data,
          topics
        )
    END AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] IN (controller_renewed_sig, controller_v5_renewed_sig)
)
SELECT
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Extract fields from decoded data array
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    decoded_data[SAFE_OFFSET(0)] AS name, -- string name/label (decoded with full Unicode support)
    SAFE_CAST(decoded_data[SAFE_OFFSET(2)] AS INT64) AS cost,    -- cost (total renewal cost)
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64) AS expires, -- expires timestamp
    -- Note: NameRenewed events do NOT have separate base_cost/premium fields
    NULL AS base_cost,
    NULL AS premium,
    -- Extract referrer (only for Controller v5)
    CASE
        WHEN topics[SAFE_OFFSET(0)] = controller_v5_renewed_sig THEN
            decoded_data[SAFE_OFFSET(4)]                          -- referrer
        ELSE NULL
    END AS referrer
FROM decoded_events;