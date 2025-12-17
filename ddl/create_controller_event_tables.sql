-- Create decoded controller event tables
-- Phase 1: Decode NameRegistered and NameRenewed events from ALL controller versions
-- Handles Controller v1-v3 (single cost field), Controller v4 (separate baseCost/premium fields),
-- and Controller v5 (baseCost/premium/referrer fields)

-- Uses ens-manager.token.decode_log function for proper Unicode support
-- Event signatures are computed using ens-manager.token.get_topic_hash function

-- NOTE: Events with extremely long data (>50KB) are excluded as they cause decode_log to fail.
-- These are rare edge cases with unusually long names that the UDF cannot handle.

-- Set event signature variables
DECLARE controller_v5_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(string label, bytes32 indexed labelhash, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires, bytes32 referrer)');
DECLARE controller_v5_renewed_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRenewed(string label, bytes32 indexed labelhash, uint256 cost, uint256 expires, bytes32 referrer)');
DECLARE controller_v4_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires)');
DECLARE controller_v1_registered_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 cost, uint256 expires)');
DECLARE controller_renewed_sig STRING DEFAULT `ens-manager.token.get_topic_hash`('NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires)');

-- Create decoded NameRegistered events table using ens-manager.token.decode_log
-- NOTE: Using UNION ALL instead of CASE because BigQuery evaluates all CASE branches,
-- causing decode_log to fail when it tries to decode events with mismatched ABIs.
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_controller_NameRegistered` AS

-- Controller v5 events (with referrer)
SELECT
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    CONCAT('0x', SUBSTR(topics[SAFE_OFFSET(2)], 27)) AS owner,     -- address owner (indexed)
    decoded_data[SAFE_OFFSET(0)] AS name, -- string label (decoded with full Unicode support)
    -- cost = baseCost + premium (BIGNUMERIC to avoid INT64 overflow for premium names > 9.22 ETH)
    SAFE_ADD(
        SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS BIGNUMERIC),
        SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS BIGNUMERIC)
    ) AS cost,
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS BIGNUMERIC) AS base_cost,
    SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS BIGNUMERIC) AS premium,
    SAFE_CAST(decoded_data[SAFE_OFFSET(5)] AS INT64) AS expires,
    decoded_data[SAFE_OFFSET(6)] AS referrer
FROM (
  SELECT *, `ens-manager.token.decode_log`(
    'NameRegistered(string label, bytes32 indexed labelhash, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires, bytes32 referrer)',
    data, topics
  ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] = controller_v5_registered_sig
    AND LENGTH(data) < 100000  -- Exclude events with extremely long data that cause decode_log to fail
)

UNION ALL

-- Controller v4 events (baseCost/premium, no referrer)
SELECT
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS label,
    CONCAT('0x', SUBSTR(topics[SAFE_OFFSET(2)], 27)) AS owner,
    decoded_data[SAFE_OFFSET(0)] AS name,
    SAFE_ADD(
        SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS BIGNUMERIC),
        SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS BIGNUMERIC)
    ) AS cost,
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS BIGNUMERIC) AS base_cost,
    SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS BIGNUMERIC) AS premium,
    SAFE_CAST(decoded_data[SAFE_OFFSET(5)] AS INT64) AS expires,
    NULL AS referrer
FROM (
  SELECT *, `ens-manager.token.decode_log`(
    'NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires)',
    data, topics
  ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] = controller_v4_registered_sig
    AND LENGTH(data) < 100000  -- Exclude events with extremely long data that cause decode_log to fail
)

UNION ALL

-- Controller v1-v3 events (single cost field)
SELECT
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS label,
    CONCAT('0x', SUBSTR(topics[SAFE_OFFSET(2)], 27)) AS owner,
    decoded_data[SAFE_OFFSET(0)] AS name,
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS BIGNUMERIC) AS cost,
    NULL AS base_cost,
    NULL AS premium,
    SAFE_CAST(decoded_data[SAFE_OFFSET(4)] AS INT64) AS expires,
    NULL AS referrer
FROM (
  SELECT *, `ens-manager.token.decode_log`(
    'NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 cost, uint256 expires)',
    data, topics
  ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] = controller_v1_registered_sig
    AND LENGTH(data) < 100000  -- Exclude events with extremely long data that cause decode_log to fail
);

-- Create decoded NameRenewed events table using ens-manager.token.decode_log
-- NOTE: Using UNION ALL instead of CASE because BigQuery evaluates all CASE branches,
-- causing decode_log to fail when it tries to decode events with mismatched ABIs.
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_controller_NameRenewed` AS

-- Controller v5 events (with referrer)
SELECT
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    decoded_data[SAFE_OFFSET(0)] AS name, -- string label (decoded with full Unicode support)
    SAFE_CAST(decoded_data[SAFE_OFFSET(2)] AS BIGNUMERIC) AS cost,    -- cost (total renewal cost, BIGNUMERIC to avoid overflow)
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64) AS expires, -- expires timestamp
    -- Note: NameRenewed events do NOT have separate base_cost/premium fields
    NULL AS base_cost,
    NULL AS premium,
    decoded_data[SAFE_OFFSET(4)] AS referrer
FROM (
  SELECT *, `ens-manager.token.decode_log`(
    'NameRenewed(string label, bytes32 indexed labelhash, uint256 cost, uint256 expires, bytes32 referrer)',
    data, topics
  ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] = controller_v5_renewed_sig
    AND LENGTH(data) < 100000  -- Exclude events with extremely long data that cause decode_log to fail
)

UNION ALL

-- Controller v1-v4 events (no referrer)
SELECT
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    decoded_data[SAFE_OFFSET(0)] AS name, -- string name (decoded with full Unicode support)
    SAFE_CAST(decoded_data[SAFE_OFFSET(2)] AS BIGNUMERIC) AS cost,    -- cost (total renewal cost, BIGNUMERIC to avoid overflow)
    SAFE_CAST(decoded_data[SAFE_OFFSET(3)] AS INT64) AS expires, -- expires timestamp
    NULL AS base_cost,
    NULL AS premium,
    NULL AS referrer
FROM (
  SELECT *, `ens-manager.token.decode_log`(
    'NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires)',
    data, topics
  ) AS decoded_data
  FROM `web3-publicgoods.ens._raw_controller_events`
  WHERE topics[SAFE_OFFSET(0)] = controller_renewed_sig
    AND LENGTH(data) < 100000  -- Exclude events with extremely long data that cause decode_log to fail
);