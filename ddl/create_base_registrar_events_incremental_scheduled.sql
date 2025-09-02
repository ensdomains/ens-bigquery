-- Incremental base registrar event decoding for scheduled queries
-- This version updates the decoded events incrementally based on new raw events

-- Create decoded NameMigrated events table if not exists
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._decoded_base_registrar_NameMigrated` (
  block_timestamp TIMESTAMP,
  block_number INT64,
  log_index INT64,
  transaction_hash STRING,
  address STRING,
  id STRING,
  owner STRING,
  expires INT64,
  labelhash STRING
);

-- Insert only new decoded NameMigrated events
INSERT INTO `web3-publicgoods.ens._decoded_base_registrar_NameMigrated` 
(block_timestamp, block_number, log_index, transaction_hash, address, id, owner, expires, labelhash)
WITH new_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data
  FROM `web3-publicgoods.ens._raw_base_registrar_events`
  WHERE topics[SAFE_OFFSET(0)] = '0xea3d7e1195a15d2ddcd859b01abd4c6b960fa9f9264e499a70a90c7f0c64b717'  -- NameMigrated
  AND block_timestamp > IFNULL(
    (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._decoded_base_registrar_NameMigrated`),
    TIMESTAMP('2019-05-04')
  )
)
SELECT
  block_timestamp,
  block_number,
  log_index,
  transaction_hash,
  address,
  topics[SAFE_OFFSET(1)] AS id,
  CONCAT('0x', SUBSTR(topics[SAFE_OFFSET(2)], 27)) AS owner,
  CAST(CONCAT('0x', data) AS INT64) AS expires,
  topics[SAFE_OFFSET(1)] AS labelhash
FROM new_events
WHERE NOT EXISTS (
  SELECT 1 FROM `web3-publicgoods.ens._decoded_base_registrar_NameMigrated` existing
  WHERE existing.transaction_hash = new_events.transaction_hash
  AND existing.log_index = new_events.log_index
);

-- Create decoded NameRegistered events table if not exists
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._decoded_base_registrar_NameRegistered` (
  block_timestamp TIMESTAMP,
  block_number INT64,
  log_index INT64,
  transaction_hash STRING,
  address STRING,
  id STRING,
  owner STRING,
  expires INT64,
  labelhash STRING
);

-- Insert only new decoded NameRegistered events
INSERT INTO `web3-publicgoods.ens._decoded_base_registrar_NameRegistered`
(block_timestamp, block_number, log_index, transaction_hash, address, id, owner, expires, labelhash)
WITH new_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data
  FROM `web3-publicgoods.ens._raw_base_registrar_events`
  WHERE topics[SAFE_OFFSET(0)] = '0xb3d987963d01b2f68493b4bdb130988f157ea43070d4ad840fee0466ed9370d9'  -- NameRegistered
  AND block_timestamp > IFNULL(
    (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._decoded_base_registrar_NameRegistered`),
    TIMESTAMP('2019-05-04')
  )
)
SELECT
  block_timestamp,
  block_number,
  log_index,
  transaction_hash,
  address,
  topics[SAFE_OFFSET(1)] AS id,
  CONCAT('0x', SUBSTR(topics[SAFE_OFFSET(2)], 27)) AS owner,
  CAST(CONCAT('0x', data) AS INT64) AS expires,
  topics[SAFE_OFFSET(1)] AS labelhash
FROM new_events
WHERE NOT EXISTS (
  SELECT 1 FROM `web3-publicgoods.ens._decoded_base_registrar_NameRegistered` existing
  WHERE existing.transaction_hash = new_events.transaction_hash
  AND existing.log_index = new_events.log_index
);

-- Create decoded NameRenewed events table if not exists  
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._decoded_base_registrar_NameRenewed` (
  block_timestamp TIMESTAMP,
  block_number INT64,
  log_index INT64,
  transaction_hash STRING,
  address STRING,
  id STRING,
  expires INT64,
  labelhash STRING
);

-- Insert only new decoded NameRenewed events
INSERT INTO `web3-publicgoods.ens._decoded_base_registrar_NameRenewed`
(block_timestamp, block_number, log_index, transaction_hash, address, id, expires, labelhash)
WITH new_events AS (
  SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    topics,
    data
  FROM `web3-publicgoods.ens._raw_base_registrar_events`
  WHERE topics[SAFE_OFFSET(0)] = '0x9b87a00e30f1ac65d898f070f8a3488fe60517182d0a2098e1b4b93a54aa9bd6'  -- NameRenewed
  AND block_timestamp > IFNULL(
    (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._decoded_base_registrar_NameRenewed`),
    TIMESTAMP('2019-05-04')
  )
)
SELECT
  block_timestamp,
  block_number,
  log_index,
  transaction_hash,
  address,
  topics[SAFE_OFFSET(1)] AS id,
  CAST(CONCAT('0x', data) AS INT64) AS expires,
  topics[SAFE_OFFSET(1)] AS labelhash
FROM new_events
WHERE NOT EXISTS (
  SELECT 1 FROM `web3-publicgoods.ens._decoded_base_registrar_NameRenewed` existing
  WHERE existing.transaction_hash = new_events.transaction_hash
  AND existing.log_index = new_events.log_index
);