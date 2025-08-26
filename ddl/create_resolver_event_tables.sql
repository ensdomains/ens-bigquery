-- Create resolver event tables by parsing raw data directly
-- Uses proper ABI decoding for data fields that contain encoded strings/bytes
-- ======================
-- RESOLVER EVENTS
-- ======================

-- Note: DECODE_ABI_STRING and DECODE_ABI_BOOL functions are defined in create_functions.sql

-- Resolver ABIChanged events (bytes32 node, uint256 contentType)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_ABIChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS contentType
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ABIChanged(bytes32,uint256)");

-- Resolver AddrChanged events (bytes32 node, address a)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_AddrChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CONCAT('0x', SUBSTR(data, 27)) AS a
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AddrChanged(bytes32,address)");

-- Resolver AddressChanged events (bytes32 node, uint256 coinType, bytes newAddress)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_AddressChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Extract coinType from first 32 bytes of data
  CAST(CONCAT('0x', SUBSTR(data, 3, 64)) AS INT64) AS coinType,
  -- Extract newAddress from remaining data (simplified - actual parsing more complex for dynamic bytes)
  CONCAT('0x', SUBSTR(data, 131)) AS newAddress,
  data AS raw_data
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AddressChanged(bytes32,uint256,bytes)");

-- Resolver AuthorisationChanged events (bytes32 node, address owner, address target, bool isAuthorised)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_AuthorisationChanged` AS
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
  -- Decode boolean from data field
  `web3-publicgoods.ens.DECODE_ABI_BOOL`(data) AS isAuthorised,
  data AS raw_data
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AuthorisationChanged(bytes32,address,address,bool)");

-- Resolver ContenthashChanged events (bytes32 node, bytes hash)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_ContenthashChanged` AS
WITH extracted_contenthashes AS (
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    address,
    topics[SAFE_OFFSET(1)] AS node,
    -- Raw ABI-encoded data
    data AS content_hash,
    -- Extract actual contenthash from ABI-encoded data
    CASE 
      WHEN LENGTH(data) > 130 AND CAST(CONCAT('0x', SUBSTR(data, 67, 64)) AS INT64) > 0 
      THEN SUBSTR(data, 131, CAST(CONCAT('0x', SUBSTR(data, 67, 64)) AS INT64) * 2)
      ELSE NULL
    END AS raw_contenthash
  FROM `web3-publicgoods.ens.raw_resolver_events`
  WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ContenthashChanged(bytes32,bytes)")
)
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  node,
  content_hash,
  raw_contenthash,
  -- Decode contenthash to human-readable format (e.g., IPFS hash)
  CASE 
    WHEN raw_contenthash IS NOT NULL AND raw_contenthash != ''
    THEN `web3-publicgoods.ens.decodeContentHashCustom`(raw_contenthash)
    ELSE NULL
  END AS decoded_contenthash,
  -- Get content type (e.g., 'ipfs', 'ipns', 'swarm')  
  CASE 
    WHEN raw_contenthash IS NOT NULL AND raw_contenthash != ''
    THEN `web3-publicgoods.ens.getContentHashCodec`(raw_contenthash)
    ELSE NULL
  END AS content_type
FROM extracted_contenthashes;

-- Resolver InterfaceChanged events (bytes32 node, bytes4 interfaceID, address implementer)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_InterfaceChanged` AS
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
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("InterfaceChanged(bytes32,bytes4,address)");

-- Resolver NameChanged events (bytes32 node, string name)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_NameChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Decode string name from data field
  `web3-publicgoods.ens.DECODE_ABI_STRING`(data, 1) AS domain_name,
  data AS raw_data
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameChanged(bytes32,string)");

-- Resolver PubkeyChanged events (bytes32 node, bytes32 x, bytes32 y)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_PubkeyChanged` AS
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
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("PubkeyChanged(bytes32,bytes32,bytes32)");

-- Resolver TextChanged events - v3 format (bytes32 node, string indexedKey, string key)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_TextChanged_v3` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS indexedKey,
  -- Decode the key string from data field
  `web3-publicgoods.ens.DECODE_ABI_STRING`(data, 1) AS text_key,
  'v3' AS version,
  data AS raw_data
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TextChanged(bytes32,string,string)");

-- Resolver TextChanged events - v4 format (bytes32 node, string indexedKey, string key, string value)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_TextChanged_v4` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS indexedKey,
  -- Decode key from first string parameter
  `web3-publicgoods.ens.DECODE_ABI_STRING`(data, 1) AS text_key,
  -- Decode value from second string parameter  
  `web3-publicgoods.ens.DECODE_ABI_STRING`(data, 2) AS text_value,
  'v4' AS version,
  data AS raw_data
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TextChanged(bytes32,string,string,string)");

-- Resolver VersionChanged events (bytes32 node, uint64 newVersion)
CREATE OR REPLACE TABLE `web3-publicgoods.ens.decoded_resolver_VersionChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS newVersion
FROM `web3-publicgoods.ens.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("VersionChanged(bytes32,uint64)");