-- Create aggregated tables for registry data  
-- These tables aggregate multiple events/values for analytics

-- ======================
-- REGISTRY AGGREGATED TABLES
-- ======================

-- Create UDF for computing ENS nodes
CREATE TEMP FUNCTION COMPUTE_ENS_NODE(parent_node STRING, label_hash STRING)
RETURNS STRING
LANGUAGE js
OPTIONS (
  library=["gs://blockchain-etl-bigquery/ethers.js"])
AS r"""
  var utils = ethers.utils;
  if(parent_node === null || label_hash === null) return null;
  try{
    var parent = parent_node.startsWith('0x') ? parent_node.slice(2) : parent_node;
    var label = label_hash.startsWith('0x') ? label_hash.slice(2) : label_hash;
    var combined = '0x' + parent + label;
    return utils.keccak256(combined);
  }catch(e){
    return null;
  }
""";

-- Node hierarchy and parent-child relationships
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.agg_registry_hierarchy` AS
WITH deduplicated_events AS (
  -- Deduplicate NewOwner events (some transactions emit duplicate events)
  SELECT 
    node,
    label,
    owner,
    block_timestamp,
    block_number,
    transaction_hash,
    log_index,
    ROW_NUMBER() OVER (
      PARTITION BY node, label, block_number, transaction_hash 
      ORDER BY log_index
    ) as rn
  FROM `web3-publicgoods.ens_temp2.decoded_registry_NewOwner`
),
parent_child_mapping AS (
  -- Build actual parent-child relationships from deduplicated NewOwner events
  -- Keep only the FIRST creation of each child node (domains can be re-registered)
  SELECT 
    parent_node,
    label_hash,
    child_node,
    initial_owner,
    created_at
  FROM (
    SELECT 
      node as parent_node,
      label as label_hash,
      COMPUTE_ENS_NODE(node, label) as child_node,
      owner as initial_owner,
      block_timestamp as created_at,
      ROW_NUMBER() OVER (
        PARTITION BY COMPUTE_ENS_NODE(node, label)  -- Partition by child node
        ORDER BY block_timestamp, log_index
      ) as creation_number
    FROM deduplicated_events
    WHERE rn = 1  -- Keep only the first event from duplicate sets
  )
  WHERE creation_number = 1  -- Keep only the first creation of each child node
),
-- First, recursively build parent names
parent_names AS (
  SELECT 
    child_node,
    parent_node,
    label_hash,
    initial_owner,
    created_at
  FROM parent_child_mapping
),
hierarchy_with_names AS (
  SELECT 
    pcm.*,
    l.label as child_label,
    -- Identify parent type
    CASE 
      WHEN parent_node = '0x0000000000000000000000000000000000000000000000000000000000000000' THEN 'root'
      WHEN parent_node = '0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae' THEN 'eth'
      WHEN parent_node = '0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34' THEN 'reverse'
      WHEN parent_node = '0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2' THEN 'addr.reverse'
      ELSE NULL
    END as parent_type,
    -- Build name based on parent - for now just use simple label
    -- Full hierarchical names will be built in a separate step
    COALESCE(l.label, CONCAT('[', SUBSTR(label_hash, 3, 8), '...]')) as simple_name
  FROM parent_child_mapping pcm
  LEFT JOIN `web3-publicgoods.ens_temp2.labels` l
    ON pcm.label_hash = CONCAT('0x', TO_HEX(l.labelHash))
),
-- For now, store simple names in hierarchy table
-- Full hierarchical names will be built in the final registry table
names_with_parents AS (
  SELECT 
    hwn.*,
    -- Build name based on parent type only (not recursive)
    CASE 
      WHEN hwn.parent_node = '0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae' 
        THEN CONCAT(hwn.simple_name, '.eth')
      WHEN hwn.parent_node = '0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2'
        THEN CONCAT(SUBSTR(hwn.label_hash, 3, 42), '.addr.reverse')
      WHEN hwn.parent_node = '0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34'
        THEN CONCAT(hwn.simple_name, '.reverse')
      WHEN hwn.parent_node = '0x0000000000000000000000000000000000000000000000000000000000000000'
        THEN hwn.simple_name
      ELSE hwn.simple_name  -- Store just the label for subdomains
    END as full_name
  FROM hierarchy_with_names hwn
)
SELECT 
  child_node as node,
  parent_node,
  label_hash,
  child_label as label_text,
  full_name as name,
  parent_type,
  created_at as creation_timestamp,
  initial_owner as creator
FROM names_with_parents;

-- Registry activity and ownership history  
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.agg_registry_activity` AS
WITH all_events AS (
  SELECT node, owner, block_timestamp, 'NewOwner' AS event_type
  FROM `web3-publicgoods.ens_temp2.decoded_registry_NewOwner`
  
  UNION ALL
  
  SELECT node, owner, block_timestamp, 'Transfer' AS event_type  
  FROM `web3-publicgoods.ens_temp2.decoded_registry_Transfer`
  
  UNION ALL
  
  SELECT node, resolver AS owner, block_timestamp, 'NewResolver' AS event_type
  FROM `web3-publicgoods.ens_temp2.decoded_registry_NewResolver`
),
node_activity AS (
  SELECT 
    node,
    COUNT(*) AS total_events,
    COUNT(DISTINCT event_type) AS unique_event_types,
    COUNT(DISTINCT owner) AS unique_owners,
    MIN(block_timestamp) AS first_activity,
    MAX(block_timestamp) AS last_activity,
    ARRAY_AGG(DISTINCT event_type ORDER BY event_type) AS event_types
  FROM all_events
  GROUP BY node
)
SELECT 
  node,
  total_events,
  unique_event_types,  
  unique_owners,
  first_activity,
  last_activity,
  event_types,
  -- Calculate activity metrics
  TIMESTAMP_DIFF(last_activity, first_activity, DAY) AS activity_days,
  CASE 
    WHEN TIMESTAMP_DIFF(last_activity, first_activity, DAY) > 0
    THEN CAST(total_events AS FLOAT64) / TIMESTAMP_DIFF(last_activity, first_activity, DAY)
    ELSE CAST(total_events AS FLOAT64)
  END AS events_per_day
FROM node_activity;