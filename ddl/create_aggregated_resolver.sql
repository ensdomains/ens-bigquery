-- Create aggregated tables for resolver data
-- These tables aggregate multiple events/values into collections
-- for easier querying and analysis

-- ======================
-- AGGREGATED TABLES - Collections of data per resolver+node
-- ======================

-- Aggregate all text record keys (from TextChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_aggregated_resolver_texts` AS
WITH all_text_events AS (
  -- Combine v3 TextChanged events (key only)
  SELECT 
    address, 
    node, 
    indexedKey,
    text_key AS key_value,
    NULL AS text_value,
    block_timestamp,
    'v3' AS version
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v3`
  
  UNION ALL
  
  -- Combine v4 TextChanged events (key and value)
  SELECT 
    address, 
    node, 
    indexedKey,
    text_data AS key_value, -- Contains both key and value encoded
    text_data AS text_value, -- Will need proper parsing
    block_timestamp,
    'v4' AS version
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v4`
),
latest_text_per_key AS (
  -- Get the latest value for each text key
  SELECT 
    address,
    node,
    indexedKey,
    key_value,
    text_value,
    version,
    block_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, indexedKey
      ORDER BY block_timestamp DESC
    ) AS rn
  FROM all_text_events
),
unique_text_keys AS (
  -- Get unique text keys that have been set with their latest timestamp
  SELECT 
    address,
    node,
    indexedKey,
    block_timestamp
  FROM latest_text_per_key
  WHERE rn = 1
    -- Filter out cleared/null text records if needed
    AND indexedKey IS NOT NULL
    AND indexedKey != ''
)
SELECT 
  address,
  node,
  ARRAY_AGG(indexedKey ORDER BY indexedKey) AS text_keys,
  STRING_AGG(indexedKey ORDER BY indexedKey) AS text_keys_csv,
  COUNT(*) AS text_keys_count,
  MAX(block_timestamp) AS last_updated_timestamp
FROM unique_text_keys
GROUP BY address, node;

-- Aggregate all multi-chain addresses (from AddressChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_aggregated_resolver_addresses` AS
WITH latest_addresses AS (
  -- Get latest address for each coinType
  SELECT 
    address,
    node,
    coinType,
    newAddress,
    block_timestamp,
    block_number,
    log_index,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, coinType 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AddressChanged`
),
active_addresses AS (
  SELECT 
    address,
    node,
    coinType,
    newAddress,
    block_timestamp
  FROM latest_addresses
  WHERE rn = 1
    -- Filter out cleared addresses (0x00...)
    AND newAddress != '0x'
    AND newAddress != '0x0000000000000000000000000000000000000000'
    AND LENGTH(newAddress) > 2
)
SELECT 
  address,
  node,
  -- Array of structs for programmatic access
  ARRAY_AGG(
    STRUCT(coinType, newAddress)
    ORDER BY coinType
  ) AS addresses_array,
  -- JSON-like string for compatibility
  CONCAT('{', 
    STRING_AGG(
      CONCAT('"', CAST(coinType AS STRING), '":"', newAddress, '"'),
      ','
      ORDER BY coinType
    ),
  '}') AS addresses_json,
  -- CSV of coinTypes for easy filtering
  STRING_AGG(
    CAST(coinType AS STRING),
    ','
    ORDER BY coinType
  ) AS supported_cointypes,
  COUNT(*) AS address_count,
  MAX(block_timestamp) AS last_updated_timestamp
FROM active_addresses
GROUP BY address, node;

-- Aggregate text values with their latest state (v4 events with values)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_aggregated_resolver_text_values` AS
WITH text_v4_parsed AS (
  -- This would need proper ABI decoding of the data field
  -- For now, storing raw data - would need to parse the string values
  SELECT 
    address,
    node,
    indexedKey,
    text_data, -- Contains encoded key and value
    block_timestamp,
    block_number,
    transaction_hash,
    log_index,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, indexedKey
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v4`
),
latest_text_values AS (
  SELECT 
    address,
    node,
    indexedKey AS text_key,
    text_data AS text_value, -- Would need proper parsing
    block_timestamp,
    block_number,
    transaction_hash
  FROM text_v4_parsed
  WHERE rn = 1
)
SELECT 
  address,
  node,
  -- Store as array of key-value pairs
  ARRAY_AGG(
    STRUCT(
      text_key,
      text_value,
      block_timestamp,
      block_number,
      transaction_hash
    )
    ORDER BY text_key
  ) AS text_records,
  -- Also create a JSON representation for easier querying
  CONCAT('{',
    STRING_AGG(
      CONCAT('"', text_key, '":"', text_value, '"'),
      ','
      ORDER BY text_key
    ),
  '}') AS text_records_json,
  COUNT(*) AS text_record_count,
  MAX(block_timestamp) AS last_updated_timestamp
FROM latest_text_values
GROUP BY address, node;

-- Create a combined view of all resolver activity
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_aggregated_resolver_activity` AS
WITH all_events AS (
  SELECT address, node, block_timestamp, 'AddrChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AddrChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'AddressChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AddressChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'TextChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v3`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'TextChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_TextChanged_v4`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'ContenthashChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_ContenthashChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'NameChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_NameChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'PubkeyChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_PubkeyChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'ABIChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_ABIChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'InterfaceChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_InterfaceChanged`
  
  UNION ALL
  
  SELECT address, node, block_timestamp, 'AuthorisationChanged' AS event_type
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AuthorisationChanged`
)
SELECT 
  address,
  node,
  COUNT(*) AS total_events,
  COUNT(DISTINCT event_type) AS unique_event_types,
  MIN(block_timestamp) AS first_activity,
  MAX(block_timestamp) AS last_activity,
  ARRAY_AGG(DISTINCT event_type ORDER BY event_type) AS event_types,
  -- Calculate activity frequency
  TIMESTAMP_DIFF(MAX(block_timestamp), MIN(block_timestamp), DAY) AS activity_days,
  CASE 
    WHEN TIMESTAMP_DIFF(MAX(block_timestamp), MIN(block_timestamp), DAY) > 0
    THEN CAST(COUNT(*) AS FLOAT64) / TIMESTAMP_DIFF(MAX(block_timestamp), MIN(block_timestamp), DAY)
    ELSE CAST(COUNT(*) AS FLOAT64)
  END AS events_per_day
FROM all_events
GROUP BY address, node;