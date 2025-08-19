-- Create resolver event tables by parsing raw data directly
-- Uses proper ABI decoding for data fields that contain encoded strings/bytes
-- ======================
-- RESOLVER EVENTS
-- ======================

-- Create ABI decoder function for strings
CREATE TEMP FUNCTION
  DECODE_ABI_STRING(data STRING, param_index INT64)
  RETURNS STRING
  LANGUAGE js AS """
    try {
      if (!data || data.length < 2) return null;
      
      // Remove 0x prefix
      const hex = data.substr(2);
      
      // Get the offset for the parameter (64 chars per offset)
      const offsetStart = (param_index - 1) * 64;
      const offsetHex = hex.substr(offsetStart, 64);
      const offset = parseInt(offsetHex, 16);
      
      // Convert byte offset to hex position (2 hex chars per byte)
      const dataStart = offset * 2;
      
      // Get length (next 64 hex chars after offset)
      const lengthHex = hex.substr(dataStart, 64);
      const length = parseInt(lengthHex, 16);
      
      if (length === 0) return '';
      
      // Get the actual string data
      const stringStart = dataStart + 64;
      const stringHex = hex.substr(stringStart, length * 2);
      
      // Convert hex to UTF-8 string
      let result = '';
      for (let i = 0; i < stringHex.length; i += 2) {
        const byte = parseInt(stringHex.substr(i, 2), 16);
        if (byte !== 0) {  // Skip null bytes
          result += String.fromCharCode(byte);
        }
      }
      
      return result;
    } catch(e) {
      return null;
    }
""";

-- Create function to decode boolean from data
CREATE TEMP FUNCTION
  DECODE_ABI_BOOL(data STRING)
  RETURNS BOOL
  LANGUAGE js AS """
    try {
      if (!data || data.length < 66) return null;
      const hex = data.substr(2);
      const boolHex = hex.substr(hex.length - 2, 2);
      return parseInt(boolHex, 16) === 1;
    } catch(e) {
      return null;
    }
""";

-- Resolver ABIChanged events (bytes32 node, uint256 contentType)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_ABIChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  topics[SAFE_OFFSET(2)] AS contentType
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ABIChanged(bytes32,uint256)");

-- Resolver AddrChanged events (bytes32 node, address a)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_AddrChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CONCAT('0x', SUBSTR(data, 27)) AS a
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AddrChanged(bytes32,address)");

-- Resolver AddressChanged events (bytes32 node, uint256 coinType, bytes newAddress)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_AddressChanged` AS
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
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AddressChanged(bytes32,uint256,bytes)");

-- Resolver AuthorisationChanged events (bytes32 node, address owner, address target, bool isAuthorised)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_AuthorisationChanged` AS
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
  DECODE_ABI_BOOL(data) AS isAuthorised,
  data AS raw_data
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("AuthorisationChanged(bytes32,address,address,bool)");

-- Resolver ContenthashChanged events (bytes32 node, bytes hash)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_ContenthashChanged` AS
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
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("ContenthashChanged(bytes32,bytes)");

-- Resolver InterfaceChanged events (bytes32 node, bytes4 interfaceID, address implementer)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_InterfaceChanged` AS
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
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("InterfaceChanged(bytes32,bytes4,address)");

-- Resolver NameChanged events (bytes32 node, string name)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_NameChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  -- Decode string name from data field
  DECODE_ABI_STRING(data, 1) AS domain_name,
  data AS raw_data
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameChanged(bytes32,string)");

-- Resolver PubkeyChanged events (bytes32 node, bytes32 x, bytes32 y)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_PubkeyChanged` AS
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
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("PubkeyChanged(bytes32,bytes32,bytes32)");

-- Resolver TextChanged events - v3 format (bytes32 node, string indexedKey, string key)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_TextChanged_v3` AS
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
  DECODE_ABI_STRING(data, 1) AS text_key,
  'v3' AS version,
  data AS raw_data
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TextChanged(bytes32,string,string)");

-- Resolver TextChanged events - v4 format (bytes32 node, string indexedKey, string key, string value)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_TextChanged_v4` AS
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
  DECODE_ABI_STRING(data, 1) AS text_key,
  -- Decode value from second string parameter  
  DECODE_ABI_STRING(data, 2) AS text_value,
  'v4' AS version,
  data AS raw_data
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("TextChanged(bytes32,string,string,string)");

-- Resolver VersionChanged events (bytes32 node, uint64 newVersion)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_resolver_VersionChanged` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS node,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS newVersion
FROM `web3-publicgoods.ens_temp2.raw_resolver_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("VersionChanged(bytes32,uint64)");