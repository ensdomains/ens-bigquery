-- Create ENS registry table using state tables (consistent with resolver approach)
-- This table tracks ownership, resolvers, and builds human-readable names

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.registry` AS
WITH all_nodes AS (
  -- Get all unique nodes from state tables
  SELECT DISTINCT node FROM `web3-publicgoods.ens_temp2.state_registry_owners`
  UNION DISTINCT
  SELECT DISTINCT node FROM `web3-publicgoods.ens_temp2.state_registry_resolvers`
  UNION DISTINCT  
  SELECT DISTINCT node FROM `web3-publicgoods.ens_temp2.state_registry_labels`
),
registry_combined AS (
  SELECT 
    an.node,
    -- Get label hash from state or hierarchy
    COALESCE(ah.label_hash, sl.labelHash) as labelHash,
    -- Get parent node from hierarchy
    ah.parent_node as parentNode,
    -- Get current owner
    so.owner,
    -- Get current resolver  
    COALESCE(sr.resolver, '0x0000000000000000000000000000000000000000') AS resolver,
    -- Keep simple name from hierarchy for now
    ah.name as simple_name,
    ah.label_text
  FROM all_nodes an
  
  -- Join with state tables
  LEFT JOIN `web3-publicgoods.ens_temp2.state_registry_owners` so
    ON an.node = so.node
    
  LEFT JOIN `web3-publicgoods.ens_temp2.state_registry_resolvers` sr
    ON an.node = sr.node
    
  LEFT JOIN `web3-publicgoods.ens_temp2.state_registry_labels` sl
    ON an.node = sl.node
    
  LEFT JOIN `web3-publicgoods.ens_temp2.agg_registry_hierarchy` ah
    ON an.node = ah.node
),
-- Build hierarchical names with parent lookups
names_with_hierarchy AS (
  SELECT 
    rc.*,
    -- Build full hierarchical name by looking up parent names
    CASE 
      -- First-level domains (.eth, .reverse, etc)
      WHEN rc.simple_name IS NOT NULL AND rc.simple_name LIKE '%.eth' THEN rc.simple_name
      WHEN rc.simple_name IS NOT NULL AND rc.simple_name LIKE '%.reverse' THEN rc.simple_name
      -- Subdomains - look up parent name
      WHEN rc.label_text IS NOT NULL AND p1.simple_name LIKE '%.eth' 
        THEN CONCAT(rc.label_text, '.', p1.simple_name)
      WHEN rc.label_text IS NOT NULL AND p1.label_text IS NOT NULL AND p2.simple_name LIKE '%.eth'
        THEN CONCAT(rc.label_text, '.', p1.label_text, '.', p2.simple_name)
      WHEN rc.label_text IS NOT NULL AND p1.label_text IS NOT NULL AND p2.label_text IS NOT NULL AND p3.simple_name LIKE '%.eth'
        THEN CONCAT(rc.label_text, '.', p1.label_text, '.', p2.label_text, '.', p3.simple_name)
      -- Default fallback
      ELSE COALESCE(rc.simple_name, CONCAT('[', SUBSTR(rc.labelHash, 3, 8), '...]'))
    END as name
  FROM registry_combined rc
  -- Join with parent (1 level up)
  LEFT JOIN registry_combined p1 ON rc.parentNode = p1.node
  -- Join with grandparent (2 levels up)
  LEFT JOIN registry_combined p2 ON p1.parentNode = p2.node
  -- Join with great-grandparent (3 levels up)
  LEFT JOIN registry_combined p3 ON p2.parentNode = p3.node
)
SELECT 
  node,
  labelHash, 
  parentNode,
  COALESCE(owner, '0x0000000000000000000000000000000000000000') AS owner,
  resolver,
  name
FROM names_with_hierarchy
-- Include all nodes that have any registry activity (owner, resolver, or label)
WHERE owner IS NOT NULL 
   OR resolver != '0x0000000000000000000000000000000000000000'
   OR labelHash IS NOT NULL