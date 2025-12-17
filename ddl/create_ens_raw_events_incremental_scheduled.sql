-- Incremental raw events extraction for scheduled queries
-- This version appends new events to existing tables instead of recreating them
-- Designed to work with BigQuery scheduled queries without checkpoint dependency

-- Raw ENS Registry events (incremental append)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._raw_registry_events` (
  block_hash STRING,
  block_number INT64,
  block_timestamp TIMESTAMP,
  transaction_hash STRING,
  transaction_index INT64,
  log_index INT64,
  address STRING,
  data STRING,
  topics ARRAY<STRING>
);

-- Insert only new registry events since last run
INSERT INTO `web3-publicgoods.ens._raw_registry_events`
(block_hash, block_number, block_timestamp, transaction_hash, transaction_index, log_index, address, data, topics)
SELECT 
  block_hash,
  block_number,
  block_timestamp,
  transaction_hash,
  transaction_index,
  log_index,
  address,
  data,
  topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
  '0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e',  -- Current ENS Registry
  '0x314159265dd8dbb310642f98f50c066173c1259b'   -- Legacy ENS Registry
)
AND block_timestamp > IFNULL(
  (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._raw_registry_events`),
  TIMESTAMP('2017-05-04')  -- ENS launch date
)
AND block_number > IFNULL(
  (SELECT MAX(block_number) FROM `web3-publicgoods.ens._raw_registry_events`),
  0
);

-- Raw Resolver events (incremental append)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._raw_resolver_events` (
  block_hash STRING,
  block_number INT64,
  block_timestamp TIMESTAMP,
  transaction_hash STRING,
  transaction_index INT64,
  log_index INT64,
  address STRING,
  data STRING,
  topics ARRAY<STRING>
);

-- Insert only new resolver events since last run
INSERT INTO `web3-publicgoods.ens._raw_resolver_events`
(block_hash, block_number, block_timestamp, transaction_hash, transaction_index, log_index, address, data, topics)
SELECT 
  block_hash,
  block_number,
  block_timestamp,
  transaction_hash,
  transaction_index,
  log_index,
  address,
  data,
  topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
  '0x231b0ee14048e9dccd1d247744d114a4eb5e8e63',  -- PublicResolver v2 (current)
  '0x4976fb03c32e5b8cfe2b6ccb31c09ba78ebaba41',  -- PublicResolver v1
  '0xd3ddccdd3b25a8a7423b5bee360a42146eb4baf3',  -- PublicResolver (old)
  '0xdaaf96c344f63131acadd0ea35170e7892d3dfba',  -- PublicResolver (old)
  '0x226159d592e2b063810a10ebf6dcbada94ed68b8',  -- PublicResolver (old)
  '0x1da022710df5002339274aadee8d58218e9d6ab5',  -- PublicResolver (2018)
  '0x5fbb459c49bb06083c33109fa4f14810ec2cf358',  -- Old resolver with event issues
  '0xa2c122be93b0074270ebee7f6b7292c7deb45047'   -- Another old resolver
)
AND block_timestamp > IFNULL(
  (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._raw_resolver_events`),
  TIMESTAMP('2017-05-04')
)
AND block_number > IFNULL(
  (SELECT MAX(block_number) FROM `web3-publicgoods.ens._raw_resolver_events`),
  0
);

-- Raw ETHRegistrarController events (incremental append)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._raw_controller_events` (
  block_hash STRING,
  block_number INT64,
  block_timestamp TIMESTAMP,
  transaction_hash STRING,
  transaction_index INT64,
  log_index INT64,
  address STRING,
  data STRING,
  topics ARRAY<STRING>
);

-- Insert only new controller events since last run
INSERT INTO `web3-publicgoods.ens._raw_controller_events`
(block_hash, block_number, block_timestamp, transaction_hash, transaction_index, log_index, address, data, topics)
SELECT 
  block_hash,
  block_number,
  block_timestamp,
  transaction_hash,
  transaction_index,
  log_index,
  address,
  data,
  topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
  '0x59e16fccd424cc24e280be16e11bcd56fb0ce547'  -- ETHRegistrarController v3 (current)
  '0x253553366da8546fc250f225fe3d25d0c782303b',  -- ETHRegistrarController v2
  '0x283af0b28c62c092c9727f1ee09c02ca627eb7f5',  -- ETHRegistrarController v1
  '0xf0ad5cad05e10572efceb849f6ff0c68f9700455',  -- ETHRegistrarController (old)
  '0xb22c1c159d12461ea124b0deb4b5b93020e6ad16'   -- ETHRegistrarController (old)
)
AND block_timestamp > IFNULL(
  (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._raw_controller_events`),
  TIMESTAMP('2019-05-04')  -- Controller launch
)
AND block_number > IFNULL(
  (SELECT MAX(block_number) FROM `web3-publicgoods.ens._raw_controller_events`),
  0
);

-- Raw BaseRegistrarImplementation events (incremental append)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._raw_base_registrar_events` (
  block_hash STRING,
  block_number INT64,
  block_timestamp TIMESTAMP,
  transaction_hash STRING,
  transaction_index INT64,
  log_index INT64,
  address STRING,
  data STRING,
  topics ARRAY<STRING>
);

-- Insert only new base registrar events since last run
INSERT INTO `web3-publicgoods.ens._raw_base_registrar_events`
(block_hash, block_number, block_timestamp, transaction_hash, transaction_index, log_index, address, data, topics)
SELECT 
  block_hash,
  block_number,
  block_timestamp,
  transaction_hash,
  transaction_index,
  log_index,
  address,
  data,
  topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address = '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85'  -- BaseRegistrarImplementation
AND block_timestamp > IFNULL(
  (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._raw_base_registrar_events`),
  TIMESTAMP('2019-05-04')
)
AND block_number > IFNULL(
  (SELECT MAX(block_number) FROM `web3-publicgoods.ens._raw_base_registrar_events`),
  0
);

-- Raw NameWrapper events (incremental append)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._raw_name_wrapper_events` (
  block_hash STRING,
  block_number INT64,
  block_timestamp TIMESTAMP,
  transaction_hash STRING,
  transaction_index INT64,
  log_index INT64,
  address STRING,
  data STRING,
  topics ARRAY<STRING>
);

-- Insert only new name wrapper events since last run
INSERT INTO `web3-publicgoods.ens._raw_name_wrapper_events`
(block_hash, block_number, block_timestamp, transaction_hash, transaction_index, log_index, address, data, topics)
SELECT 
  block_hash,
  block_number,
  block_timestamp,
  transaction_hash,
  transaction_index,
  log_index,
  address,
  data,
  topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address = '0xd4416b13d2b3a9abae7acd5d6c2bbdbe25686401'  -- NameWrapper
AND block_timestamp > IFNULL(
  (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._raw_name_wrapper_events`),
  TIMESTAMP('2022-05-04')  -- NameWrapper launch
)
AND block_number > IFNULL(
  (SELECT MAX(block_number) FROM `web3-publicgoods.ens._raw_name_wrapper_events`),
  0
);

-- Raw old registrar events for historical data (incremental append)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._raw_registrar_events` (
  block_hash STRING,
  block_number INT64,
  block_timestamp TIMESTAMP,
  transaction_hash STRING,
  transaction_index INT64,
  log_index INT64,
  address STRING,
  data STRING,
  topics ARRAY<STRING>
);

-- Insert only new old registrar events since last run
INSERT INTO `web3-publicgoods.ens._raw_registrar_events`
(block_hash, block_number, block_timestamp, transaction_hash, transaction_index, log_index, address, data, topics)
SELECT 
  block_hash,
  block_number,
  block_timestamp,
  transaction_hash,
  transaction_index,
  log_index,
  address,
  data,
  topics
FROM `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
WHERE address IN (
  '0x6090a6e47849629b7245dfa1ca21d94cd15878ef',  -- Legacy .eth Registrar (auction)
  '0xfac7bea255a6990f749363002136af6556b31e04'   -- Legacy .eth Registrar (2017)
)
AND block_timestamp > IFNULL(
  (SELECT MAX(block_timestamp) FROM `web3-publicgoods.ens._raw_registrar_events`),
  TIMESTAMP('2017-05-04')
)
AND block_number > IFNULL(
  (SELECT MAX(block_number) FROM `web3-publicgoods.ens._raw_registrar_events`),
  0
);