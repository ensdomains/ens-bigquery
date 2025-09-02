-- Create checkpoint table for tracking pipeline progress
-- This table stores the last processed block number to enable incremental updates
-- for the expensive raw event extraction stages

-- Initialize checkpoint table (safe for first run)
CREATE TABLE IF NOT EXISTS `web3-publicgoods.ens._pipeline_checkpoint` (
  last_processed_block INT64,
  last_updated TIMESTAMP,
  status STRING,
  blocks_processed INT64,
  events_processed INT64
);

-- Insert initial checkpoint if table is empty
INSERT INTO `web3-publicgoods.ens._pipeline_checkpoint` (
  last_processed_block,
  last_updated,
  status,
  blocks_processed,
  events_processed
)
SELECT 
  0 as last_processed_block,
  CURRENT_TIMESTAMP() as last_updated,
  'initialized' as status,
  0 as blocks_processed,
  0 as events_processed
FROM (SELECT 1) dummy
WHERE NOT EXISTS (SELECT 1 FROM `web3-publicgoods.ens._pipeline_checkpoint`);

-- Add comment for documentation
ALTER TABLE `web3-publicgoods.ens._pipeline_checkpoint`
SET OPTIONS (
  description = 'Tracks the last processed block for incremental pipeline runs. Used by create_ens_raw_events.sql and create_base_registrar_events.sql to avoid reprocessing historical data.'
);