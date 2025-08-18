-- Create table-valued functions for decoded ENS events using existing public decode functions
-- Uses ens-manager.token.decode_log and ens-manager.token.get_topic_hash as they are public

-- 1. Registry events decoded table function
CREATE OR REPLACE TABLE FUNCTION `web3-publicgoods.ens_temp.decoded_registry_events`(event STRING) AS (
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    address,
    `ens-manager.token.decode_log`(event, data, topics) AS event_data,
  FROM
    `web3-publicgoods.ens_temp.ens_raw_registry_events`
  WHERE
    topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`(event)
);

-- 2. Resolver events decoded table function
CREATE OR REPLACE TABLE FUNCTION `web3-publicgoods.ens_temp.decoded_resolver_events`(event STRING) AS (
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    address,
    `ens-manager.token.decode_log`(event, data, topics) AS event_data,
  FROM
    `web3-publicgoods.ens_temp.ens_raw_resolver_events`
  WHERE
    topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`(event)
);

-- 3. Registrar events decoded table function
CREATE OR REPLACE TABLE FUNCTION `web3-publicgoods.ens_temp.decoded_registrar_events`(event STRING) AS (
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    address,
    `ens-manager.token.decode_log`(event, data, topics) AS event_data,
  FROM
    `web3-publicgoods.ens_temp.ens_raw_registrar_events`
  WHERE
    topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`(event)
);

-- 4. Registrar Controller events decoded table function
CREATE OR REPLACE TABLE FUNCTION `web3-publicgoods.ens_temp.decoded_registrar_controller_events`(event STRING) AS (
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    address,
    `ens-manager.token.decode_log`(event, data, topics) AS event_data,
  FROM
    `web3-publicgoods.ens_temp.ens_raw_registrar_controller_events`
  WHERE
    topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`(event)
);

-- 5. Name Wrapper events decoded table function
CREATE OR REPLACE TABLE FUNCTION `web3-publicgoods.ens_temp.decoded_name_wrapper_events`(event STRING) AS (
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    address,
    `ens-manager.token.decode_log`(event, data, topics) AS event_data,
  FROM
    `web3-publicgoods.ens_temp.ens_raw_name_wrapper_events`
  WHERE
    topics[SAFE_OFFSET(0)] = `ens-manager.token.get_topic_hash`(event)
);