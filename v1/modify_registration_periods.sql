SELECT
  labelhash,
  label,
  event_timestamp,
  start_time,
  end_time,
  CAST(cost AS float64) / 1e18 AS cost,
  LAST_VALUE(ether_price IGNORE NULLS) OVER (prev_win) AS ether_price,
  event
FROM ( (
    SELECT
      labelhash,
      LAST_VALUE(label IGNORE NULLS) OVER(PARTITION BY labelhash ORDER BY block_timestamp, log_index ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS label,
      block_timestamp AS event_timestamp,
      GREATEST(block_timestamp, LAG(TIMESTAMP_ADD(timestamp "1970-01-01 00:00:00+00", INTERVAL CAST(expires AS int64) SECOND), 1, timestamp "1970-01-01 00:00:00+00") OVER (PARTITION BY labelhash ORDER BY block_timestamp, log_index)) AS start_time,
      TIMESTAMP_ADD(timestamp "1970-01-01 00:00:00+00", INTERVAL CAST(expires AS int64) SECOND) AS end_time,
      cost,
      NULL AS ether_price,
      event
    FROM (
      SELECT
        `ens-manager.airdrop.int_str_to_hash`(id) AS labelhash,
        NULL AS label,
        owner,
        block_timestamp,
        log_index,
        expires,
        "0" AS cost,
        'migrated' AS event
      FROM
        `blockchain-etl.ethereum_ens.BaseRegistrarImplementation_event_NameMigrated`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'registered' AS event
      FROM
        `blockchain-etl.ethereum_ens.ETHRegistrarController_event_NameRegistered`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'renewed' AS event
      FROM
        `blockchain-etl.ethereum_ens.ETHRegistrarController_event_NameRenewed`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'registered' AS event
      FROM
        `blockchain-etl.ethereum_ens.ETHRegistrarController2_event_NameRegistered`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'renewed' AS event
      FROM
        `blockchain-etl.ethereum_ens.ETHRegistrarController2_event_NameRenewed`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'registered' AS event
      FROM
        `blockchain-etl.ethereum_ens.ETHRegistrarController3_event_NameRegistered`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'renewed' AS event
      FROM
        `blockchain-etl.ethereum_ens.ETHRegistrarController3_event_NameRenewed`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cast(cast(baseCost AS float64) + cast(premium AS float64) AS string) AS cost,
        'registered' AS event
      FROM
        `ens-manager.names.ETHRegistrarController4_event_NameRegistered`
      UNION ALL
      SELECT
        label AS labelhash,
        name AS label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'renewed' AS event
      FROM
        `ens-manager.names.ETHRegistrarController4_event_NameRenewed_fixed`
      UNION ALL
      SELECT
        labelhash,
        label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cast(cast(baseCost AS float64) + cast(premium AS float64) AS string) AS cost,
        'registered' AS event
      FROM
        `ens-manager.names.ETHRegistrarController5_event_NameRegistered`
      UNION ALL
      SELECT
        labelhash,
        label,
        NULL AS owner,
        block_timestamp,
        log_index,
        expires,
        cost,
        'renewed' AS event
      FROM
        `ens-manager.names.ETHRegistrarController5_event_NameRenewed_fixed` ) AS events
    WHERE
      1 = 1 QUALIFY TIMESTAMP_DIFF(end_time, start_time, SECOND) > 0 )
  UNION ALL
  SELECT
    NULL AS labelhash,
    NULL AS label,
    block_timestamp AS event_timestamp,
    NULL AS start_time,
    NULL AS end_time,
    NULL AS cost,
    1e12*CAST(reserve0 AS float64)/CAST(reserve1 AS float64) AS ether_price,
    NULL AS event
  FROM
    `blockchain-etl.ethereum_uniswap.UniswapV2Pair_event_Sync`
  WHERE
    contract_address = "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc")
WHERE
  1=1 QUALIFY labelhash IS NOT NULL
WINDOW
  prev_win AS (
  ORDER BY
    event_timestamp ROWS BETWEEN UNBOUNDED PRECEDING
    AND CURRENT ROW)
ORDER BY
  event_timestamp