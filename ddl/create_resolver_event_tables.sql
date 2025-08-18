-- Create resolver event tables by parsing raw data directly
-- ======================
-- RESOLVER EVENTS
-- ======================

-- Resolver ABIChanged events (bytes32 node, uint256 contentType)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_ABIChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS contentType
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ABIChanged(bytes32,uint256)");

-- Resolver AddrChanged events (bytes32 node, address a)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AddrChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CONCAT('0x', SUBSTR(data, 27)) AS a
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AddrChanged(bytes32,address)");

-- Resolver AddressChanged events (bytes32 node, uint256 coinType, bytes newAddress)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AddressChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Parse data field for coinType and newAddress (simplified)
  data
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AddressChanged(bytes32,uint256,bytes)");

-- Resolver AuthorisationChanged events (bytes32 node, address owner, address target, bool isAuthorised)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AuthorisationChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS owner,
  topics[SAFE_OFFSET(3)] AS target,
  -- Parse data field for isAuthorised boolean (simplified)
  data
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AuthorisationChanged(bytes32,address,address,bool)");

-- Resolver ContenthashChanged events (bytes32 node, bytes hash)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_ContenthashChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Parse data field for hash bytes (simplified)
  data AS content_hash
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ContenthashChanged(bytes32,bytes)");

-- Resolver InterfaceChanged events (bytes32 node, bytes4 interfaceID, address implementer)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_InterfaceChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS interfaceID,
  CONCAT('0x', SUBSTR(data, 27)) AS implementer
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("InterfaceChanged(bytes32,bytes4,address)");

-- Resolver NameChanged events (bytes32 node, string name)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_NameChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Parse data field for string name (simplified)
  data AS domain_name
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameChanged(bytes32,string)");

-- Resolver PubkeyChanged events (bytes32 node, bytes32 x, bytes32 y)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_PubkeyChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Parse data field for x and y (simplified)
  SUBSTR(data, 3, 64) AS x,
  SUBSTR(data, 67, 64) AS y
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("PubkeyChanged(bytes32,bytes32,bytes32)");

-- Resolver TextChanged events - v3 format (bytes32 node, string indexedKey, string key)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v3` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS indexedKey,
  -- Parse data field for key (simplified)
  data AS text_key,
  'v3' AS version
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TextChanged(bytes32,string,string)");

-- Resolver TextChanged events - v4 format (bytes32 node, string indexedKey, string key, string value)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v4` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS indexedKey,
  -- Parse data field for key and value (simplified)
  data AS text_data,
  'v4' AS version
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TextChanged(bytes32,string,string,string)");

-- Resolver VersionChanged events (bytes32 node, uint64 newVersion)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_decoded_resolver_event_VersionChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS newVersion
FROM `web3-publicgoods.ens_temp.ens_raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("VersionChanged(bytes32,uint64)");