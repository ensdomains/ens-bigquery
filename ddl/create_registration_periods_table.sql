-- Create registration periods table from decoded controller events
-- Phase 2: Aggregate decoded events into time periods with proper start/end times
-- Based on ens-manager.registrations.registration_periods_view structure

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.registration_periods` AS
SELECT
  labelhash,
  label,
  event_timestamp,
  start_time,
  end_time,
  CAST(cost AS FLOAT64) / 1e18 AS cost,
  event
FROM (
  SELECT
    transaction_hash,
    labelhash,
    LAST_VALUE(label IGNORE NULLS) OVER(
      PARTITION BY labelhash 
      ORDER BY block_timestamp, log_index 
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS label,
    block_timestamp AS event_timestamp,
    log_index,
    -- Key ens-manager logic: Use LAG to get previous expiry as start time
    GREATEST(
      block_timestamp, 
      LAG(
        TIMESTAMP_SECONDS(CAST(expires AS INT64)), 
        1, 
        TIMESTAMP("1970-01-01 00:00:00+00")
      ) OVER (
        PARTITION BY labelhash 
        ORDER BY block_timestamp, log_index
      )
    ) AS start_time,
    TIMESTAMP_SECONDS(CAST(expires AS INT64)) AS end_time,
    cost,
    event
  FROM (
    -- Registration events from our decoded controller tables
    SELECT
      transaction_hash,
      label AS labelhash,
      name AS label,
      owner,
      block_timestamp,
      log_index,
      expires,
      cost,
      'registered' AS event
    FROM `web3-publicgoods.ens_temp2.decoded_controller_NameRegistered`
    WHERE expires IS NOT NULL AND cost IS NOT NULL 
      AND expires > 0 AND expires < 2000000000  -- Filter reasonable Unix timestamps (before year 2033)
    
    UNION ALL
    
    -- Renewal events from our decoded controller tables
    SELECT
      transaction_hash,
      label AS labelhash,
      name AS label,
      NULL AS owner,
      block_timestamp,
      log_index,
      expires,
      cost,
      'renewed' AS event
    FROM `web3-publicgoods.ens_temp2.decoded_controller_NameRenewed`
    WHERE expires IS NOT NULL AND cost IS NOT NULL 
      AND expires > 0 AND expires < 2000000000  -- Filter reasonable Unix timestamps (before year 2033)
    
    UNION ALL
    
    -- Migration events from our decoded base registrar tables
    SELECT
      transaction_hash,
      labelhash AS labelhash,
      COALESCE(l.label, 'unknown') AS label,
      NULL AS owner,  -- Not needed for migration processing
      block_timestamp,
      log_index,
      expires,
      0 AS cost,  -- Migrations were free
      'migrated' AS event
    FROM `web3-publicgoods.ens_temp2.decoded_base_registrar_NameMigrated` m
    LEFT JOIN `web3-publicgoods.ens_temp2.labels` l
      ON l.labelHash = FROM_HEX(SUBSTR(m.labelhash, 3))  -- Remove 0x prefix for comparison
    WHERE expires IS NOT NULL 
      AND expires > 0 AND expires < 2000000000  -- Filter reasonable Unix timestamps
  ) AS events
  WHERE labelhash IS NOT NULL
  -- Add the ens-manager QUALIFY filter to ensure positive time periods
  QUALIFY TIMESTAMP_DIFF(TIMESTAMP_SECONDS(CAST(expires AS INT64)), start_time, SECOND) > 0
)
WHERE labelhash IS NOT NULL
ORDER BY event_timestamp;