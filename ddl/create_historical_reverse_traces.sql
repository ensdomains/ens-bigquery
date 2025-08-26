-- One-time extraction of historical setName() calls from traces
-- Captures reverse names from old resolvers that didn't emit events properly
-- This supplements the main pipeline with historical data

-- Create decode function for setName(bytes32,string) calls
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.DECODE_SET_NAME`(input STRING)
RETURNS STRUCT<node STRING, name STRING>
LANGUAGE js AS """
  // setName function signature: 0x77372213
  if (!input || !input.startsWith('0x77372213')) return {node: null, name: null};
  
  try {
    // Remove function selector (first 4 bytes / 8 chars + 0x = 10 chars)
    const data = input.substring(10);
    
    // First 32 bytes (64 chars) = node (bytes32)
    const node = '0x' + data.substring(0, 64);
    
    // Next 32 bytes (64 chars) = offset to string data (should be 0x40 = 64)
    const stringOffset = parseInt(data.substring(64, 128), 16);
    
    // Next 32 bytes = string length
    const stringLengthHex = data.substring(128, 192);
    const stringLength = parseInt(stringLengthHex, 16);
    
    // Actual string data (UTF-8 encoded)
    const stringDataHex = data.substring(192, 192 + stringLength * 2);
    
    // Convert hex to string
    let name = '';
    for (let i = 0; i < stringDataHex.length; i += 2) {
      const byte = parseInt(stringDataHex.substr(i, 2), 16);
      if (byte > 0) {
        name += String.fromCharCode(byte);
      }
    }
    
    return {node: node, name: name};
  } catch(e) {
    return {node: null, name: null};
  }
""";

-- Extract historical traces from old resolvers
-- These addresses had known issues with event emission
CREATE OR REPLACE TABLE `web3-publicgoods.ens.historical_reverse_traces` AS
SELECT
  block_number,
  block_timestamp,
  transaction_hash,
  to_address AS resolver_address,
  decoded.node AS node,
  decoded.name AS domain_name,
  'historical_trace' AS source
FROM (
  SELECT 
    block_number,
    block_timestamp,
    transaction_hash,
    to_address,
    `web3-publicgoods.ens.DECODE_SET_NAME`(input) AS decoded
  FROM `bigquery-public-data.crypto_ethereum.traces`
  WHERE to_address IN (
    '0x5fbb459c49bb06083c33109fa4f14810ec2cf358',  -- Old resolver with event issues
    '0xa2c122be93b0074270ebee7f6b7292c7deb45047'   -- Another old resolver
  )
  AND SUBSTR(input, 1, 10) = '0x77372213'  -- setName function selector
  AND trace_type = 'call'
  AND status = 1  -- Only successful calls
)
WHERE decoded.node IS NOT NULL 
  AND decoded.name IS NOT NULL
  AND decoded.name != '';