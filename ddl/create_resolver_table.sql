-- Create the final resolvers table by combining state and aggregated data
-- This table contains the current resolver configuration for each node
-- Matches the schema defined in table_documentation.md

CREATE OR REPLACE TABLE `web3-publicgoods.ens.resolvers` AS
WITH all_resolver_nodes AS (
  -- Get all unique resolver+node combinations from all sources
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._state_resolver_eth_addresses`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._state_resolver_contenthashes`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._state_resolver_reverse_names`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._agg_resolver_text_records`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._agg_resolver_addresses`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._state_resolver_pubkeys`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._state_resolver_abi`
  
  UNION DISTINCT
  
  SELECT DISTINCT address, node 
  FROM `web3-publicgoods.ens._state_resolver_interfaces`
),
resolver_data_combined AS (
  SELECT 
    arn.address,
    arn.node,
    -- Primary ETH address (addr field)
    eth.addr,
    -- Text records as array of structs (key, value)
    COALESCE(txtr.text_records, []) AS text_records,
    -- Text keys as CSV string for backward compatibility
    COALESCE(txtr.text_keys_csv, '') AS texts,
    -- Multi-chain addresses as JSON string
    COALESCE(addr.addresses_json, '{}') AS addresses,
    -- Content hash (raw hex)
    ch.contenthash,
    -- Extract raw contenthash from ABI-encoded data
    CASE 
      WHEN ch.contenthash IS NOT NULL AND LENGTH(ch.contenthash) > 130 
           AND CAST(CONCAT('0x', SUBSTR(ch.contenthash, 67, 64)) AS INT64) > 0 
      THEN SUBSTR(ch.contenthash, 131, CAST(CONCAT('0x', SUBSTR(ch.contenthash, 67, 64)) AS INT64) * 2)
      ELSE NULL
    END AS raw_contenthash,
    -- Reverse name (for reverse resolvers)
    rn.reverseName,
    -- Additional metadata
    GREATEST(
      eth.last_updated_timestamp,
      ch.last_updated_timestamp,
      rn.last_updated_timestamp,
      txtr.last_updated_timestamp,
      addr.last_updated_timestamp
    ) AS last_updated
  FROM all_resolver_nodes arn
  
  -- Join state tables (latest values)
  LEFT JOIN `web3-publicgoods.ens._state_resolver_eth_addresses` eth
    ON arn.address = eth.address AND arn.node = eth.node
    
  LEFT JOIN `web3-publicgoods.ens._state_resolver_contenthashes` ch
    ON arn.address = ch.address AND arn.node = ch.node
    
  LEFT JOIN `web3-publicgoods.ens._state_resolver_reverse_names` rn
    ON arn.address = rn.address AND arn.node = rn.node
  
  -- Join aggregated tables (collections)
  LEFT JOIN `web3-publicgoods.ens._agg_resolver_text_records` txtr
    ON arn.address = txtr.address AND arn.node = txtr.node
    
  LEFT JOIN `web3-publicgoods.ens._agg_resolver_addresses` addr
    ON arn.address = addr.address AND arn.node = addr.node
)
SELECT
  -- Keep address and node as STRING (they're already hex strings from topics)
  address,
  node,
  -- Keep addr as STRING
  addr,
  -- Text records as array of structs (key, value) - MAIN FIELD FOR QUERYING
  text_records,
  -- Keep texts as STRING (CSV of text keys) for backward compatibility
  texts,
  -- Keep addresses as STRING (JSON mapping)
  addresses,
  -- Keep contenthash as hex string
  contenthash,
  -- Raw contenthash extracted from ABI encoding
  raw_contenthash,
  -- Decoded contenthash (human-readable format)
  CASE 
    WHEN raw_contenthash IS NOT NULL AND raw_contenthash != ''
    THEN `web3-publicgoods.ens.decodeContentHashCustom`(raw_contenthash)
    ELSE NULL
  END AS decoded_contenthash,
  -- Content type (codec)
  CASE 
    WHEN raw_contenthash IS NOT NULL AND raw_contenthash != ''
    THEN `web3-publicgoods.ens.getContentHashCodec`(raw_contenthash)
    ELSE NULL
  END AS content_type,
  -- Keep reverseName as STRING
  reverseName
FROM resolver_data_combined
-- Filter out completely empty resolver records if needed
WHERE addr IS NOT NULL 
   OR ARRAY_LENGTH(text_records) > 0
   OR addresses != '{}'
   OR contenthash IS NOT NULL
   OR raw_contenthash IS NOT NULL
   OR reverseName IS NOT NULL;

-- Drop and recreate clustered table (clustering spec cannot be changed with CREATE OR REPLACE)
DROP TABLE IF EXISTS `web3-publicgoods.ens.resolvers_clustered`;

-- Create a clustered version for better query performance
CREATE TABLE `web3-publicgoods.ens.resolvers_clustered`
CLUSTER BY address, node
AS 
SELECT * FROM `web3-publicgoods.ens.resolvers`;

-- Create a view with additional computed fields for easier querying
CREATE OR REPLACE VIEW `web3-publicgoods.ens.resolvers_extended` AS
SELECT
  address,
  node,
  addr,
  texts,
  -- Parse text keys for counting
  CASE 
    WHEN texts = '' THEN 0
    ELSE ARRAY_LENGTH(SPLIT(texts, ','))
  END AS text_count,
  addresses,
  -- Extract number of multi-chain addresses
  ARRAY_LENGTH(
    REGEXP_EXTRACT_ALL(addresses, r'"(\d+)":')
  ) AS address_count,
  contenthash,
  raw_contenthash,
  decoded_contenthash,
  content_type,
  reverseName,
  -- Check if this is a reverse record (nodes under addr.reverse namespace)
  CASE
    WHEN STARTS_WITH(node, '0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2') 
    THEN TRUE
    ELSE FALSE
  END AS is_reverse_record
FROM `web3-publicgoods.ens.resolvers`;

-- Create summary statistics table for monitoring
CREATE OR REPLACE TABLE `web3-publicgoods.ens._resolvers_stats` AS
SELECT
  COUNT(*) AS total_resolver_records,
  COUNT(DISTINCT address) AS unique_resolver_addresses,
  COUNT(DISTINCT node) AS unique_nodes,
  COUNT(addr) AS nodes_with_eth_address,
  COUNT(CASE WHEN texts != '' THEN 1 END) AS nodes_with_text_records,
  COUNT(CASE WHEN addresses != '{}' THEN 1 END) AS nodes_with_multichain_addresses,
  COUNT(contenthash) AS nodes_with_contenthash,
  COUNT(raw_contenthash) AS nodes_with_raw_contenthash,
  COUNT(decoded_contenthash) AS nodes_with_decoded_contenthash,
  COUNT(CASE WHEN content_type = 'ipfs' THEN 1 END) AS nodes_with_ipfs_content,
  COUNT(CASE WHEN content_type = 'ipns' THEN 1 END) AS nodes_with_ipns_content,
  COUNT(CASE WHEN content_type = 'swarm' THEN 1 END) AS nodes_with_swarm_content,
  COUNT(reverseName) AS nodes_with_reverse_name,
  CURRENT_TIMESTAMP() AS stats_generated_at
FROM `web3-publicgoods.ens.resolvers`;