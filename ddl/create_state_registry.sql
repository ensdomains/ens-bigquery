-- Create state tables for registry data
-- These tables contain the latest state for each node from registry events

-- ======================
-- REGISTRY STATE TABLES
-- ======================

-- Latest ownership state for each node
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_registry_owners` AS
WITH all_ownership_changes AS (
  -- NewOwner events
  SELECT 
    node,
    owner,
    block_timestamp,
    block_number,
    log_index,
    transaction_hash
  FROM `web3-publicgoods.ens._decoded_registry_NewOwner`
  
  UNION ALL
  
  -- Transfer events  
  SELECT 
    node,
    owner,
    block_timestamp,
    block_number,
    log_index,
    transaction_hash
  FROM `web3-publicgoods.ens._decoded_registry_Transfer`
),
latest_owners AS (
  SELECT 
    node,
    owner,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY node 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM all_ownership_changes
)
SELECT 
  node,
  owner,
  block_timestamp AS last_updated_timestamp,
  block_number AS last_updated_block,
  transaction_hash AS last_updated_tx
FROM latest_owners
WHERE rn = 1;

-- Latest resolver state for each node
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_registry_resolvers` AS
WITH latest_resolvers AS (
  SELECT 
    node,
    resolver,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY node 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_registry_NewResolver`
)
SELECT 
  node,
  resolver,
  block_timestamp AS last_updated_timestamp,
  block_number AS last_updated_block,
  transaction_hash AS last_updated_tx
FROM latest_resolvers
WHERE rn = 1;

-- Node hierarchy and labels (from NewOwner events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_registry_labels` AS
WITH latest_node_creation AS (
  SELECT 
    node,
    label AS labelHash,
    owner AS creator,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY node 
      ORDER BY block_timestamp ASC, log_index ASC  -- First occurrence
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_registry_NewOwner`
)
SELECT 
  node,
  labelHash,
  creator,
  block_timestamp AS creation_timestamp,
  block_number AS creation_block,
  transaction_hash AS creation_tx
FROM latest_node_creation
WHERE rn = 1;