-- Create registry event tables by parsing raw data directly
-- ======================
-- REGISTRY EVENTS
-- ======================

-- Registry Transfer events (bytes32 node, address owner)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_registry_event_Transfer` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CONCAT('0x', SUBSTR(data, 27)) AS owner
FROM `web3-publicgoods.ens_temp.ens_raw_registry_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("Transfer(bytes32,address)");

-- Registry NewOwner events (bytes32 node, bytes32 label, address owner)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_registry_event_NewOwner` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS label,
  CONCAT('0x', SUBSTR(data, 27)) AS owner
FROM `web3-publicgoods.ens_temp.ens_raw_registry_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NewOwner(bytes32,bytes32,address)");

-- Registry NewResolver events (bytes32 node, address resolver)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_registry_event_NewResolver` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CONCAT('0x', SUBSTR(data, 27)) AS resolver
FROM `web3-publicgoods.ens_temp.ens_raw_registry_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NewResolver(bytes32,address)");

-- Registry NewTTL events (bytes32 node, uint64 ttl)
-- Gets "Bad int64 value: 0x000000000000000000000000000000..." error
-- 
-- CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_registry_event_NewTTL` AS
-- SELECT
--   transaction_hash,
--   block_number,
--   block_timestamp,
--   block_hash,
--   log_index,
--   address,
--   topics[SAFE_OFFSET(1)] AS node,
--   CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS ttl
-- FROM `web3-publicgoods.ens_temp.ens_raw_registry_events`
-- WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NewTTL(bytes32,uint64)");