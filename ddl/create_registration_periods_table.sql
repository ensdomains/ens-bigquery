-- Create registration periods table from decoded controller events with USD cost derivation
-- Phase 2: Aggregate decoded events into time periods with proper start/end times
-- Phase 3: Add USD cost calculations using ENS pricing structure
-- Based on ens-manager.registrations.registration_periods_view structure

CREATE OR REPLACE TABLE `web3-publicgoods.ens.registration_periods` AS
WITH base_registration_periods AS (
SELECT
  labelhash,
  label,
  event_timestamp,
  start_time,
  end_time,
  CAST(cost AS FLOAT64) / 1e18 AS cost,
  CAST(base_cost AS FLOAT64) / 1e18 AS base_cost_eth,
  CAST(premium AS FLOAT64) / 1e18 AS premium_eth,
  event,
  transaction_hash,
  controller_address
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
    -- Correct logic: start_time is when the registration/renewal actually happened
    block_timestamp AS start_time,
    TIMESTAMP_SECONDS(CAST(expires AS INT64)) AS end_time,
    cost,
    base_cost,
    premium,
    event,
    address as controller_address
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
      base_cost,
      premium,
      'registered' AS event,
      address
    FROM `web3-publicgoods.ens._decoded_controller_NameRegistered`    
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
      NULL AS base_cost,  -- Renewals don't have separate base_cost
      NULL AS premium,     -- Renewals don't have separate premium
      'renewed' AS event,
      address
    FROM `web3-publicgoods.ens._decoded_controller_NameRenewed`    
    UNION ALL
    
    -- Migration events from our decoded base registrar tables
    SELECT
      transaction_hash,
      m.labelhash AS labelhash,
      l.label AS label,
      NULL AS owner,  -- Not needed for migration processing
      block_timestamp,
      log_index,
      expires,
      0 AS cost,  -- Migrations were free
      NULL AS base_cost,
      NULL AS premium,
      'migrated' AS event,
      '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85' as controller_address  -- BaseRegistrar address
    FROM `web3-publicgoods.ens._decoded_base_registrar_NameMigrated` m
    LEFT JOIN `web3-publicgoods.ens.labels` l
      ON l.labelHash = FROM_HEX(SUBSTR(m.labelhash, 3))  -- Remove 0x prefix for comparison
    ) AS events
    WHERE labelhash IS NOT NULL
  )
  WHERE labelhash IS NOT NULL
),
events_with_prices AS (
-- Combine ENS events with Uniswap ETH-USD price data (similar to ens-manager approach)
SELECT 
  labelhash,
  label,
  event_timestamp,
  start_time,
  end_time,
  cost,
  base_cost_eth,
  premium_eth,
  event,
  transaction_hash,
  controller_address,
  -- Get ETH-USD price from Uniswap data using window function
  LAST_VALUE(ether_price IGNORE NULLS) OVER (
    ORDER BY event_timestamp 
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS ether_price
FROM (
  -- ENS events
  SELECT
    labelhash,
    label,
    event_timestamp,
    start_time,
    end_time,
    cost,
    base_cost_eth,
    premium_eth,
    event,
    transaction_hash,
    controller_address,
    NULL AS ether_price
  FROM base_registration_periods
  
  UNION ALL
  
  -- Uniswap ETH-USD price data
  SELECT
    NULL AS labelhash,
    NULL AS label,
    block_timestamp AS event_timestamp,
    NULL AS start_time,
    NULL AS end_time,
    NULL AS cost,
    NULL AS base_cost_eth,
    NULL AS premium_eth,
    NULL AS event,
    NULL AS transaction_hash,
    NULL AS controller_address,
    -- Convert USDC/ETH to ETH/USD (reserve0 = USDC, reserve1 = ETH)
    1e12 * CAST(reserve0 AS FLOAT64) / CAST(reserve1 AS FLOAT64) AS ether_price
  FROM `blockchain-etl.ethereum_uniswap.UniswapV2Pair_event_Sync`
  WHERE contract_address = '0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc'  -- USDC-ETH pair
)
),
enriched_periods AS (
-- Add calculated fields for premium derivation using external ETH-USD prices
SELECT 
  *,
  -- Calculate duration in years
  TIMESTAMP_DIFF(end_time, start_time, DAY) / 365.25 as duration_years,
  
  -- Base cost per year based on name length (ENS pricing: $640/3-char, $160/4-char, $5/5+-char)
  CASE 
    WHEN LENGTH(label) = 3 THEN 640.0
    WHEN LENGTH(label) = 4 THEN 160.0
    ELSE 5.0  -- 5+ chars
  END as base_cost_usd_per_year,
  
  -- Calculate theoretical base cost in USD (duration * rate)
  (CASE 
    WHEN LENGTH(label) = 3 THEN 640.0
    WHEN LENGTH(label) = 4 THEN 160.0
    ELSE 5.0
  END) * (TIMESTAMP_DIFF(end_time, start_time, DAY) / 365.25) as theoretical_base_cost_usd,
  
  -- Calculate theoretical base cost in ETH using external ETH-USD price
  -- For Controller v4: use decoded base_cost_eth if available
  -- For Controller v1-v3: use theoretical base cost USD / external ETH-USD price
  CASE 
    WHEN base_cost_eth IS NOT NULL THEN base_cost_eth  -- Controller v4 explicit base cost
    ELSE ((CASE 
      WHEN LENGTH(label) = 3 THEN 640.0
      WHEN LENGTH(label) = 4 THEN 160.0
      ELSE 5.0
    END) * (TIMESTAMP_DIFF(end_time, start_time, DAY) / 365.25)) / ether_price  -- theoretical_base_cost_usd / external_eth_usd_price
  END as theoretical_base_cost_eth
  
FROM events_with_prices 
WHERE labelhash IS NOT NULL  -- Filter to only ENS events after price window function
)
-- Final SELECT with all calculations
SELECT 
  -- Original columns
  labelhash,
  label, 
  event_timestamp,
  start_time,
  end_time,
  cost,
  event,
  transaction_hash,  -- Added for cross-checking with decoded tables
  duration_years,
  base_cost_usd_per_year,
  theoretical_base_cost_usd as base_cost_usd,
  
  -- Use external ETH-USD rate from Uniswap (same as ens-manager approach)
  ether_price as eth_usd_rate,
  
  -- Premium cost calculation (use decoded premium from Controller v4, or derive from cost difference)
  CASE 
    WHEN premium_eth IS NOT NULL THEN premium_eth  -- Controller v4 has explicit premium
    WHEN base_cost_eth IS NOT NULL AND cost > base_cost_eth THEN cost - base_cost_eth  -- Controller v4 fallback
    -- For Controller v1-v3: derive premium as total cost minus theoretical base cost in ETH
    ELSE GREATEST(0.0, cost - theoretical_base_cost_eth)
  END as premium,
  
  -- Premium USD cost using external ETH-USD rate
  (CASE 
    WHEN premium_eth IS NOT NULL THEN premium_eth  -- Controller v4 explicit premium
    WHEN base_cost_eth IS NOT NULL AND cost > base_cost_eth THEN cost - base_cost_eth  -- Controller v4 fallback
    -- For Controller v1-v3: derived premium using external price
    ELSE GREATEST(0.0, cost - theoretical_base_cost_eth)
  END) * ether_price as premium_usd

FROM enriched_periods
ORDER BY event_timestamp;