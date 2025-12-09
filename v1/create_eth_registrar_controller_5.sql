CREATE TEMP FUNCTION
  DECODE_RENEW_CALL(data STRING)
  RETURNS STRING
  LANGUAGE js AS """
  const abi = [
    "function renew(string name, uint256 duration)"
  ];
  const interface = new ethers.utils.Interface(abi);
  const tx = interface.parseTransaction({data: data})
  if(tx === null) return null;
  return tx.args[0];
""" OPTIONS ( library="gs://blockchain-etl-bigquery/ethers.js" );

CREATE TEMP FUNCTION
  HEX_TO_DECIMAL_STRING(data string)
  RETURNS STRING
  LANGUAGE js AS """
  if (data === null) return null;
  return BigInt(data).toString();
""";

CREATE OR REPLACE TABLE `ens-manager.names.ETHRegistrarController5_event_NameRenewed_fixed` AS
  WITH to_controller_traces AS (
      SELECT * FROM `ens-manager.names.controller_traces`
      WHERE to_address = "0x59e16fccd424cc24e280be16e11bcd56fb0ce547"
  ),
  from_controller_traces AS (
      SELECT * FROM `ens-manager.names.controller_traces`
      WHERE from_address = "0x59e16fccd424cc24e280be16e11bcd56fb0ce547"
  ),
  renew_traces AS (
    SELECT 
      *,
      DECODE_RENEW_CALL(input) AS name
    FROM to_controller_traces
    WHERE
      starts_with(input, "0x18026ad1")
  ),
  refund_traces AS (
      SELECT * FROM from_controller_traces
      WHERE input = "0x"
          AND value != 0
  ),
  renew_nw_traces AS (
      SELECT * FROM from_controller_traces
      WHERE starts_with(input, "0xc475abff")
          AND to_address = "0xd4416b13d2b3a9abae7acd5d6c2bbdbe25686401"
  ),
  renew_values AS (
      SELECT
          p.transaction_hash,
          p.value AS tx_value,
          c.value AS refund_value,
          CAST(p.value - c.value AS STRING) AS renewal_value,
          p.name AS name,
          HEX_TO_DECIMAL_STRING(d.output) AS expires
      FROM renew_traces p
      LEFT JOIN refund_traces c
          ON p.transaction_hash = c.transaction_hash
              AND c.trace_address = IF(p.trace_address IS NOT NULL, CONCAT(p.trace_address, ",3"), "3")
      LEFT JOIN renew_nw_traces d
          ON p.transaction_hash = d.transaction_hash
              AND d.trace_address = IF(p.trace_address IS NOT NULL, CONCAT(p.trace_address, ",2"), "2")
  )
  SELECT
      e.transaction_hash,
      e.block_number,
      e.block_timestamp,
      e.block_hash,
      e.log_index,
      e.label,
      e.name,
      e.expires,
      COALESCE(v.renewal_value, e.cost) AS cost
  FROM `ens-manager.names.ETHRegistrarController5_event_NameRenewed` e
  LEFT JOIN renew_values v
      ON e.transaction_hash = v.transaction_hash
          AND e.name = v.name
          AND e.expires = v.expires;