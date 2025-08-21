-- Create registrar controller event tables by parsing raw data directly
-- ======================
-- REGISTRAR CONTROLLER EVENTS
-- ======================

-- Controller NameRegistered events - v3 format (string name, bytes32 label, address owner, uint256 cost, uint256 expires)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_registrar_controller_NameRegistered_v3` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS label,
  topics[SAFE_OFFSET(2)] AS owner,
  -- Parse data for name, cost, expires (this is simplified - actual parsing is more complex for string + multiple uint256)
  data,
  'v3' AS version
FROM `web3-publicgoods.ens_temp2.raw_registrar_controller_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameRegistered(string,bytes32,address,uint256,uint256)");

-- Controller NameRegistered events - v4 format (string name, bytes32 label, address owner, uint256 baseCost, uint256 premium, uint256 expires)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_registrar_controller_NameRegistered_v4` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS label,
  topics[SAFE_OFFSET(2)] AS owner,
  -- Parse data for name, baseCost, premium, expires (this is simplified)
  data,
  'v4' AS version
FROM `web3-publicgoods.ens_temp2.raw_registrar_controller_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameRegistered(string,bytes32,address,uint256,uint256,uint256)");

-- Controller NameRenewed events (string name, bytes32 label, uint256 cost, uint256 expires)
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_registrar_controller_NameRenewed` AS
SELECT
  transaction_hash,
  block_number,
  block_timestamp,
  block_hash,
  log_index,
  address,
  topics[SAFE_OFFSET(1)] AS label,
  -- Parse data for name, cost, expires (simplified)
  data,
  'both' AS version -- This event format is same across v3 and v4
FROM `web3-publicgoods.ens_temp2.raw_registrar_controller_events`
WHERE topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`("NameRenewed(string,bytes32,uint256,uint256)");