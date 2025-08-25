-- Create reverse records table following ens-manager logic
-- This table maps Ethereum addresses to their primary ENS names
-- Based on the query from ens-manager.names.reverse_records

-- Note: NAMEHASH function is defined in create_functions.sql

-- Create reverse records using the proper ENS logic
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.reverse_records` AS
WITH
-- Get all ETH addresses that have been resolved (forward resolution)
resolved_addrs AS (
  SELECT DISTINCT
    node,
    addr
  FROM `web3-publicgoods.ens_temp2.state_resolver_eth_addresses`
  WHERE addr IS NOT NULL
    AND addr != '0x0000000000000000000000000000000000000000'
    AND LENGTH(addr) = 42
),
-- Get all resolvers (we'll use our resolver table)
resolvers AS (
  SELECT DISTINCT
    node,
    address AS resolver
  FROM `web3-publicgoods.ens_temp2.resolvers`
  WHERE reverseName IS NOT NULL
    AND reverseName != ''
),
-- Get names with their reverse names (from resolver reverse name data)
names AS (
  SELECT DISTINCT
    node,
    address AS resolver,
    reverseName AS name
  FROM `web3-publicgoods.ens_temp2.state_resolver_reverse_names`
  WHERE reverseName IS NOT NULL 
    AND reverseName != ''
)
-- Apply the ens-manager logic:
-- 1. Join resolved_addrs with resolvers where reverse node matches
-- 2. Join with names to get the actual name
-- 3. Validate that forward resolution matches
SELECT DISTINCT
  resolved_addrs.addr AS address,
  names.name AS name
FROM resolved_addrs
-- Join resolvers where the reverse node matches addr.reverse pattern
INNER JOIN resolvers 
  ON resolvers.node = `web3-publicgoods.ens_temp2.NAMEHASH`(CONCAT(SUBSTR(resolved_addrs.addr, 3), ".addr.reverse"))
-- Join names to get the actual ENS name
INNER JOIN names 
  ON names.resolver = resolvers.resolver 
  AND names.node = resolvers.node
-- Validate that forward resolution matches (prevents invalid reverse records)
WHERE resolved_addrs.node = `web3-publicgoods.ens_temp2.NAMEHASH`(names.name);

-- Create an unvalidated version without the validation step for debugging
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.debug_reverse_records_unvalidated` AS
WITH reverse_resolver_data AS (
  SELECT DISTINCT
    node,
    address AS resolver_address,
    reverseName AS name
  FROM `web3-publicgoods.ens_temp2.state_resolver_reverse_names`
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