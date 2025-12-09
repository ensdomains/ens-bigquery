CREATE OR REPLACE TABLE `ens-manager.names.controller_events` AS
SELECT
  *
FROM
  `bigquery-public-data.crypto_ethereum.logs`
WHERE
  address = "0x253553366da8546fc250f225fe3d25d0c782303b";

CREATE OR REPLACE TABLE `ens-manager.names.ETHRegistrarController4_event_NameRegistered` AS
  SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    event[OFFSET(0)] AS name,
    event[OFFSET(1)] AS label,
    event[OFFSET(2)] AS owner,
    event[OFFSET(3)] AS baseCost,
    event[OFFSET(4)] AS premium,
    event[OFFSET(5)] AS expires
  FROM
    `ens-manager.names.decoded_logs`("NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 baseCost, uint256 premium, uint256 expires)");

CREATE OR REPLACE TABLE `ens-manager.names.ETHRegistrarController4_event_NameRenewed` AS
    SELECT
    transaction_hash,
    block_number,
    block_timestamp,
    block_hash,
    log_index,
    event[OFFSET(0)] AS name,
    event[OFFSET(1)] AS label,
    event[OFFSET(2)] AS cost,
    event[OFFSET(3)] AS expires
  FROM
    `ens-manager.names.decoded_logs`("NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires)");
