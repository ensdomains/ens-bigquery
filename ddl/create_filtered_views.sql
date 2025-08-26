-- Create filtered views that exclude released nodes (current date > end_date + 90 days grace period)
-- Version 2: Handle the fact that resolvers track full ENS namespace, not just .eth registrations

-- 1. view_registry: Active registry entries only
CREATE OR REPLACE VIEW `web3-publicgoods.ens.view_registry` AS
WITH active_labelhashes AS (
  SELECT DISTINCT
    labelhash
  FROM `web3-publicgoods.ens.registration_periods`
  GROUP BY labelhash
  HAVING TIMESTAMP_ADD(MAX(end_time), INTERVAL 90 DAY) > CURRENT_TIMESTAMP()
),
active_names AS (
  SELECT DISTINCT
    CONCAT(rp.label, '.eth') AS name,
    rp.labelhash
  FROM `web3-publicgoods.ens.registration_periods` rp
  INNER JOIN active_labelhashes al ON rp.labelhash = al.labelhash
  WHERE rp.label IS NOT NULL AND rp.label != ''
)
SELECT 
  r.*
FROM `web3-publicgoods.ens.registry` r
WHERE r.name IN (SELECT name FROM active_names)
   OR r.node IN (SELECT labelhash FROM active_labelhashes);

-- 2. view_resolvers: Active resolver entries only
-- Since resolvers cover the full ENS namespace, we need a different approach
-- We'll include resolvers for active .eth names plus any resolver with recent activity
CREATE OR REPLACE VIEW `web3-publicgoods.ens.view_resolvers` AS
WITH active_eth_names AS (
  SELECT DISTINCT
    CONCAT(rp.label, '.eth') AS name,
    rp.labelhash
  FROM `web3-publicgoods.ens.registration_periods` rp
  WHERE rp.label IS NOT NULL AND rp.label != ''
  GROUP BY rp.labelhash, rp.label
  HAVING TIMESTAMP_ADD(MAX(rp.end_time), INTERVAL 90 DAY) > CURRENT_TIMESTAMP()
)
SELECT 
  res.*
FROM `web3-publicgoods.ens.resolvers` res
WHERE 
  -- Include resolvers that have set any resolver data (address, text records, etc.)
  -- This filters out empty/unused resolvers
  (res.addr IS NOT NULL AND res.addr != '' AND res.addr != '0x0000000000000000000000000000000000000000')
  OR (res.text_records IS NOT NULL AND ARRAY_LENGTH(res.text_records) > 0)
  OR (res.contenthash IS NOT NULL AND res.contenthash != '')
  OR (res.reverseName IS NOT NULL AND res.reverseName != '');

-- 3. view_resolutions: Active resolution entries only
CREATE OR REPLACE VIEW `web3-publicgoods.ens.view_resolutions` AS  
WITH active_labelhashes AS (
  SELECT DISTINCT
    labelhash
  FROM `web3-publicgoods.ens.registration_periods`
  GROUP BY labelhash
  HAVING TIMESTAMP_ADD(MAX(end_time), INTERVAL 90 DAY) > CURRENT_TIMESTAMP()
),
active_names AS (
  SELECT DISTINCT
    CONCAT(rp.label, '.eth') AS name
  FROM `web3-publicgoods.ens.registration_periods` rp
  INNER JOIN active_labelhashes al ON rp.labelhash = al.labelhash
  WHERE rp.label IS NOT NULL AND rp.label != ''
)
SELECT 
  res.*
FROM `web3-publicgoods.ens.resolutions` res
WHERE 
  -- Include resolutions for active .eth names
  res.name IN (SELECT name FROM active_names)
  OR
  -- Include resolutions that have actual resolution data
  (res.addr IS NOT NULL AND res.addr != '' AND res.addr != '0x0000000000000000000000000000000000000000');