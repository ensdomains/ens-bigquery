-- Create checkpoint table for tracking pipeline progress
-- This table stores the last processed block number to enable incremental updates
-- for the expensive raw event extraction stages

CREATE OR REPLACE TABLE `web3-publicgoods.ens._pipeline_checkpoint` AS
SELECT 
  COALESCE(MAX(block_number), 0) as last_processed_block,
  CURRENT_TIMESTAMP() as last_updated,
  'initialized' as status,
  0 as blocks_processed,
  0 as events_processed
FROM `web3-publicgoods.ens._raw_resolver_events`;

-- Add comment for documentation
ALTER TABLE `web3-publicgoods.ens._pipeline_checkpoint`
SET OPTIONS (
  description = 'Tracks the last processed block for incremental pipeline runs. Used by create_ens_raw_events.sql and create_base_registrar_events.sql to avoid reprocessing historical data.'
);