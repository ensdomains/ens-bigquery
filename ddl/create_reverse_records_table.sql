-- Create reverse records table following ens-manager logic
-- This table maps Ethereum addresses to their primary ENS names
-- Based on the query from ens-manager.names.reverse_records

-- Note: NAMEHASH function is defined in create_functions.sql

-- Create reverse records with forward_resolution validation column
CREATE OR REPLACE TABLE `web3-publicgoods.ens.reverse_records` AS
WITH
-- Get all addresses that have ETH address records (these are the ones that could have reverse records)
addresses_with_forward AS (
  SELECT DISTINCT
    node,
    addr AS address
  FROM `web3-publicgoods.ens._state_resolver_eth_addresses`
  WHERE addr IS NOT NULL
    AND addr != '0x0000000000000000000000000000000000000000'
    AND LENGTH(addr) = 42
),
-- Get the current resolver for each reverse node from the registry
-- This ensures we only use the reverse name from the currently active resolver
current_reverse_resolvers AS (
  SELECT
    node,
    resolver AS current_resolver
  FROM (
    SELECT
      node,
      resolver,
      ROW_NUMBER() OVER (PARTITION BY node ORDER BY block_timestamp DESC, log_index DESC) AS rn
    FROM `web3-publicgoods.ens._decoded_registry_NewResolver`
    WHERE resolver != '0x0000000000000000000000000000000000000000'
  )
  WHERE rn = 1
),
-- Get reverse record names by checking which addresses have reverse records set
-- Only use the reverse name from the CURRENTLY ACTIVE resolver for each reverse node
all_reverse_records AS (
  SELECT DISTINCT
    awf.address,
    rr.reverseName AS name
  FROM addresses_with_forward awf
  INNER JOIN current_reverse_resolvers crr
    ON crr.node = `web3-publicgoods.ens.NAMEHASH`(CONCAT(SUBSTR(awf.address, 3), ".addr.reverse"))
  INNER JOIN `web3-publicgoods.ens._state_resolver_reverse_names` rr
    ON rr.node = crr.node
    AND rr.address = crr.current_resolver  -- Only use the current resolver's reverse name
  WHERE rr.reverseName IS NOT NULL
    AND rr.reverseName != ''
),
-- Get forward resolution data
forward_resolutions AS (
  SELECT DISTINCT
    node AS forward_node,
    addr AS resolved_address
  FROM `web3-publicgoods.ens._state_resolver_eth_addresses`
  WHERE addr IS NOT NULL
    AND addr != '0x0000000000000000000000000000000000000000'
    AND LENGTH(addr) = 42
)
-- Create final table with forward_resolution validation
SELECT DISTINCT
  arr.address,
  arr.name,
  -- Check if forward resolution matches
  CASE
    WHEN fr.resolved_address = arr.address THEN TRUE
    ELSE FALSE
  END AS forward_resolution
FROM all_reverse_records arr
LEFT JOIN forward_resolutions fr
  ON fr.forward_node = `web3-publicgoods.ens.NAMEHASH`(arr.name);

-- Create an unvalidated version without the validation step for debugging
CREATE OR REPLACE TABLE `web3-publicgoods.ens._debug_reverse_records_unvalidated` AS
WITH reverse_resolver_data AS (
  SELECT DISTINCT
    node,
    address AS resolver_address,
    reverseName AS name
  FROM `web3-publicgoods.ens._state_resolver_reverse_names`
  WHERE reverseName IS NOT NULL 
    AND reverseName != ''
)
SELECT DISTINCT
  -- Extract the address from the reverse node
  -- For reverse nodes, we need to reverse the namehash process
  -- This is a simplified approach - actual implementation would decode the node
  CONCAT('0x', LOWER(SUBSTR(node, 3, 40))) AS address,
  name
FROM reverse_resolver_data
-- Filter for nodes that look like reverse records (this is approximate)
WHERE LENGTH(node) = 66  -- Standard node length
  AND STARTS_WITH(node, '0x');