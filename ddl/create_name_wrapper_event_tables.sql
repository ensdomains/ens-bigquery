-- Create name wrapper event tables by parsing raw data directly
-- ======================
-- NAME WRAPPER EVENTS
-- ======================

-- NameWrapper NameWrapped events (bytes32 node, bytes name, address owner, uint32 fuses, uint64 expiry)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_NameWrapped` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS owner,
  -- Parse data for name, fuses, expiry (simplified)
  data
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameWrapped(bytes32,bytes,address,uint32,uint64)");

-- NameWrapper NameUnwrapped events (bytes32 node, address owner)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_NameUnwrapped` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS owner
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameUnwrapped(bytes32,address)");

-- NameWrapper FusesSet events (bytes32 node, uint32 fuses)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_FusesSet` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS fuses
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("FusesSet(bytes32,uint32)");

-- NameWrapper ExpiryExtended events (bytes32 node, uint64 expiry)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_ExpiryExtended` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS expiry
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ExpiryExtended(bytes32,uint64)");

-- NameWrapper TransferSingle events (address operator, address from, address to, uint256 id, uint256 value)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_TransferSingle` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS operator,
  topics[SAFE_OFFSET(2)] AS from_address,
  topics[SAFE_OFFSET(3)] AS to_address,
  -- Parse data for id and value (simplified)
  SUBSTR(data, 3, 64) AS id,
  SUBSTR(data, 67, 64) AS text_value
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TransferSingle(address,address,address,uint256,uint256)");

-- NameWrapper TransferBatch events (address operator, address from, address to, uint256[] ids, uint256[] values)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_TransferBatch` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS operator,
  topics[SAFE_OFFSET(2)] AS from_address,
  topics[SAFE_OFFSET(3)] AS to_address,
  -- Parse data for ids and values arrays (simplified)
  data
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TransferBatch(address,address,address,uint256[],uint256[])");

-- NameWrapper ApprovalForAll events (address owner, address operator, bool approved)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_name_wrapper_event_ApprovalForAll` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS owner,
  topics[SAFE_OFFSET(2)] AS operator,
  -- Parse data for approved boolean (simplified)
  CASE WHEN CONCAT('0x', data) = '0x0000000000000000000000000000000000000000000000000000000000000001' THEN TRUE ELSE FALSE END AS approved
FROM `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ApprovalForAll(address,address,bool)");