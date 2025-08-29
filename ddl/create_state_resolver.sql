-- Create state tables for resolver data
-- These tables contain the latest state for each resolver+node combination
-- by using window functions to get the most recent value from events

-- ======================
-- STATE TABLES - Latest values per resolver+node
-- ======================

-- Latest ETH address (from AddrChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_eth_addresses` AS
WITH latest_addr AS (
  SELECT 
    address,
    node,
    a AS addr,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_resolver_AddrChanged`
)
SELECT 
  address,
  node,
  addr,
  block_timestamp AS last_updated_timestamp,
  block_number AS last_updated_block,
  transaction_hash AS last_updated_tx
FROM latest_addr
WHERE rn = 1;

-- Latest content hash (from ContenthashChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_contenthashes` AS
WITH latest_content AS (
  SELECT 
    address,
    node,
    content_hash AS contenthash,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_resolver_ContenthashChanged`
)
SELECT 
  address,
  node,
  contenthash,
  block_timestamp AS last_updated_timestamp,
  block_number AS last_updated_block,
  transaction_hash AS last_updated_tx
FROM latest_content
WHERE rn = 1;

-- Latest reverse name (from NameChanged events + historical traces)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_reverse_names` AS
WITH all_reverse_names AS (
  -- From NameChanged events (main source)
  SELECT 
    address,
    node,
    domain_name AS reverseName,
    block_timestamp,
    block_number,
    transaction_hash,
    log_index
  FROM `web3-publicgoods.ens._decoded_resolver_NameChanged`
  WHERE domain_name IS NOT NULL
  
  UNION ALL
  
  -- From historical traces (supplement for old resolvers that didn't emit events)
  -- Only include if the historical traces table exists
  SELECT 
    resolver_address AS address,
    node,
    domain_name AS reverseName,
    block_timestamp,
    block_number,
    transaction_hash,
    NULL AS log_index  -- Traces don't have log_index
  FROM `web3-publicgoods.ens._historical_reverse_traces`
  WHERE domain_name IS NOT NULL
),
latest_names AS (
  SELECT 
    address,
    node,
    reverseName,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node 
      ORDER BY block_timestamp DESC, log_index DESC NULLS LAST
    ) AS rn
  FROM all_reverse_names
  WHERE reverseName IS NOT NULL
)
SELECT 
  address,
  node,
  reverseName,
  block_timestamp AS last_updated_timestamp,
  block_number AS last_updated_block,
  transaction_hash AS last_updated_tx
FROM latest_names
WHERE rn = 1;

-- Latest pubkey (from PubkeyChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_pubkeys` AS
WITH latest_pubkeys AS (
  SELECT 
    address,
    node,
    x AS pubkey_x,
    y AS pubkey_y,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_resolver_PubkeyChanged`
)
SELECT 
  address,
  node,
  pubkey_x,
  pubkey_y,
  block_timestamp AS last_updated_timestamp,
  block_number AS last_updated_block,
  transaction_hash AS last_updated_tx
FROM latest_pubkeys
WHERE rn = 1;

-- Latest ABI (from ABIChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_abi` AS
WITH latest_abi AS (
  SELECT 
    address,
    node,
    contentType AS abi_contentType,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, contentType
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_resolver_ABIChanged`
),
aggregated_abi AS (
  SELECT 
    address,
    node,
    ARRAY_AGG(
      STRUCT(abi_contentType, block_timestamp, block_number, transaction_hash)
      ORDER BY abi_contentType
    ) AS abi_types,
    MAX(block_timestamp) AS last_updated_timestamp,
    MAX(block_number) AS last_updated_block
  FROM latest_abi
  WHERE rn = 1
  GROUP BY address, node
)
SELECT 
  address,
  node,
  abi_types,
  last_updated_timestamp,
  last_updated_block
FROM aggregated_abi;

-- Latest interface implementations (from InterfaceChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_interfaces` AS
WITH latest_interfaces AS (
  SELECT 
    address,
    node,
    interfaceID,
    implementer,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, interfaceID
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_resolver_InterfaceChanged`
),
aggregated_interfaces AS (
  SELECT 
    address,
    node,
    ARRAY_AGG(
      STRUCT(interfaceID, implementer)
      ORDER BY interfaceID
    ) AS interfaces,
    MAX(block_timestamp) AS last_updated_timestamp,
    MAX(block_number) AS last_updated_block
  FROM latest_interfaces
  WHERE rn = 1
    AND implementer != '0x0000000000000000000000000000000000000000' -- Exclude cleared interfaces
  GROUP BY address, node
)
SELECT 
  address,
  node,
  interfaces,
  last_updated_timestamp,
  last_updated_block
FROM aggregated_interfaces;

-- Latest authorizations (from AuthorisationChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._state_resolver_authorizations` AS
WITH latest_auth AS (
  SELECT 
    address,
    node,
    owner,
    target,
    isAuthorised, -- Now properly decoded boolean
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, owner, target
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens._decoded_resolver_AuthorisationChanged`
),
active_authorizations AS (
  SELECT 
    address,
    node,
    owner,
    ARRAY_AGG(
      target
      ORDER BY target
    ) AS authorized_targets,
    MAX(block_timestamp) AS last_updated_timestamp,
    MAX(block_number) AS last_updated_block
  FROM latest_auth
  WHERE rn = 1
    -- Filter for only active authorizations using decoded boolean
    AND isAuthorised = TRUE
  GROUP BY address, node, owner
)
SELECT 
  address,
  node,
  owner,
  authorized_targets,
  last_updated_timestamp,
  last_updated_block
FROM active_authorizations;