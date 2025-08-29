-- Create registrar event tables by parsing raw data directly
-- ======================
-- REGISTRAR EVENTS
-- ======================

-- BaseRegistrar NameRegistered events (uint256 id, address owner, uint256 expires)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_registrar_NameRegistered` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS id,
  topics[SAFE_OFFSET(2)] AS owner,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS expires
FROM `web3-publicgoods.ens._raw_registrar_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameRegistered(uint256,address,uint256)");

-- BaseRegistrar NameRenewed events (uint256 id, uint256 expires)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_registrar_NameRenewed` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS id,
  CAST(CONCAT('0x', SUBSTR(data, 3)) AS INT64) AS expires
FROM `web3-publicgoods.ens._raw_registrar_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameRenewed(uint256,uint256)");

-- BaseRegistrar Transfer events (address from, address to, uint256 tokenId)
CREATE OR REPLACE TABLE `web3-publicgoods.ens._decoded_registrar_Transfer` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS from_address,
  topics[SAFE_OFFSET(2)] AS to_address,
  topics[SAFE_OFFSET(3)] AS tokenId
FROM `web3-publicgoods.ens._raw_registrar_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("Transfer(address,address,uint256)");