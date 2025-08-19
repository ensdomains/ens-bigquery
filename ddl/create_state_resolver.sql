-- Create state tables for resolver data
-- These tables contain the latest state for each resolver+node combination
-- by using window functions to get the most recent value from events

-- ======================
-- STATE TABLES - Latest values per resolver+node
-- ======================

-- Latest ETH address (from AddrChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_eth_addresses` AS
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
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AddrChanged`
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
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_contenthashes` AS
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
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_ContenthashChanged`
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

-- Latest reverse name (from NameChanged events)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_reverse_names` AS
WITH latest_names AS (
  SELECT 
    address,
    node,
    domain_name AS reverseName,
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node 
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_NameChanged`
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
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_pubkeys` AS
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
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_PubkeyChanged`
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
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_abi` AS
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
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_ABIChanged`
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
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_interfaces` AS
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
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_InterfaceChanged`
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
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp.ens_state_resolver_authorizations` AS
WITH latest_auth AS (
  SELECT 
    address,
    node,
    owner,
    target,
    data AS auth_data, -- Contains the boolean authorization status
    block_timestamp,
    block_number,
    transaction_hash,
    ROW_NUMBER() OVER (
      PARTITION BY address, node, owner, target
      ORDER BY block_timestamp DESC, log_index DESC
    ) AS rn
  FROM `web3-publicgoods.ens_temp.ens_decoded_resolver_event_AuthorisationChanged`
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
    -- Filter for only active authorizations (would need to parse auth_data boolean)
    AND auth_data != '0x0000000000000000000000000000000000000000000000000000000000000000'
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