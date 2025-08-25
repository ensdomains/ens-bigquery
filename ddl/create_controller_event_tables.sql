-- Create decoded controller event tables
-- Phase 1: Decode NameRegistered and NameRenewed events from ALL controller versions
-- Handles Controller v1-v3 (single cost field) and Controller v4 (separate baseCost/premium fields)

-- Create UDF for name extraction from ABI-encoded data
CREATE TEMP FUNCTION EXTRACT_NAME_FROM_ABI_DATA(data STRING)
RETURNS STRING
LANGUAGE js AS """
  if (!data || data.length < 322) return 'unknown';
  
  // Remove 0x prefix if present
  const cleanData = data.startsWith('0x') ? data.slice(2) : data;
  
  // Check if this follows the expected ABI encoding pattern
  // First 32 bytes should be 0x60 (pointer to string data)
  const stringPointer = cleanData.substr(0, 64);
  if (stringPointer !== '0000000000000000000000000000000000000000000000000000000000000060') {
    return 'unknown';
  }
  
  // Extract string length from bytes 96-127 (hex positions 192-255)
  const lengthHex = cleanData.substr(192, 64);
  const nameLength = parseInt(lengthHex, 16);
  
  if (nameLength > 100 || nameLength === 0) return 'unknown'; // Sanity check
  
  // Extract name data starting at position 256 
  const nameHex = cleanData.substr(256, nameLength * 2);
  
  // Convert hex to ASCII string
  let name = '';
  for (let i = 0; i < nameHex.length; i += 2) {
    const charCode = parseInt(nameHex.substr(i, 2), 16);
    if (charCode >= 32 && charCode <= 126) { // Printable ASCII
      name += String.fromCharCode(charCode);
    }
  }
  
  return name || 'unknown';
""";


-- Create decoded NameRegistered events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_controller_NameRegistered` AS
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Indexed parameters from topics
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    topics[SAFE_OFFSET(2)] AS owner,     -- address owner (indexed)
    -- Extract name using JavaScript UDF
    EXTRACT_NAME_FROM_ABI_DATA(data) AS name,
    -- Extract total cost (consistent semantic across all versions)
    -- Controller v1-v3: Single cost field at offset 67 (total cost including any premium)
    -- Controller v4: Calculate total as baseCost + premium
    CASE 
        WHEN address = '0x253553366da8546fc250f225fe3d25d0c782303b' THEN  -- Controller v4
            SAFE_ADD(
                SAFE_CAST(CONCAT('0x', SUBSTR(data, 67, 64)) AS INT64),   -- baseCost at offset 67
                SAFE_CAST(CONCAT('0x', SUBSTR(data, 131, 64)) AS INT64)   -- + premium at offset 131
            )
        ELSE  -- Controller v1-v3
            SAFE_CAST(CONCAT('0x', SUBSTR(data, 67, 64)) AS INT64)        -- cost (total) at offset 67
    END AS cost,
    -- Extract baseCost (only for Controller v4)
    CASE 
        WHEN address = '0x253553366da8546fc250f225fe3d25d0c782303b' THEN  -- Controller v4
            SAFE_CAST(CONCAT('0x', SUBSTR(data, 67, 64)) AS INT64)        -- baseCost at offset 67
        ELSE NULL
    END AS base_cost,
    -- Extract premium (only for Controller v4)
    CASE 
        WHEN address = '0x253553366da8546fc250f225fe3d25d0c782303b' THEN  -- Controller v4
            SAFE_CAST(CONCAT('0x', SUBSTR(data, 131, 64)) AS INT64)       -- premium at offset 131
        ELSE NULL
    END AS premium,
    -- Extract expires with version-specific logic
    CASE 
        WHEN address = '0x253553366da8546fc250f225fe3d25d0c782303b' THEN  -- Controller v4
            SAFE_CAST(CONCAT('0x', SUBSTR(data, 195, 64)) AS INT64)       -- expires at offset 195
        ELSE  -- Controller v1-v3
            SAFE_CAST(CONCAT('0x', SUBSTR(data, 131, 64)) AS INT64)       -- expires at offset 131
    END AS expires
FROM `web3-publicgoods.ens_temp2.raw_controller_events`
WHERE topics[SAFE_OFFSET(0)] IN (
    '0xb3d987963d01b2f68493b4bdb130988f157ea43070d4ad840fee0466ed9370d9', -- NameRegistered v1
    '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27', -- NameRegistered v4 (new signature)
    '0xca6abbe9d7f11422cb6ca7629fbf6fe9efb1c621f71ce8f02b9f2a230097404f'  -- NameRegistered v1-v3
);

-- Create decoded NameRenewed events table
CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.decoded_controller_NameRenewed` AS  
SELECT 
    block_timestamp,
    block_number,
    log_index,
    transaction_hash,
    address,
    -- Indexed parameters from topics
    topics[SAFE_OFFSET(1)] AS label,     -- bytes32 labelhash (indexed)
    -- Extract name using JavaScript UDF
    EXTRACT_NAME_FROM_ABI_DATA(data) AS name,
    -- Extract cost and expires - NameRenewed ABI is consistent across all controller versions
    -- All controllers use: name(string), cost(uint256), expires(uint256)
    SAFE_CAST(CONCAT('0x', SUBSTR(data, 67, 64)) AS INT64) AS cost,
    -- All NameRenewed events have expires at offset 131
    SAFE_CAST(CONCAT('0x', SUBSTR(data, 131, 64)) AS INT64) AS expires,
    -- Note: NameRenewed events do NOT have separate base_cost/premium fields
    -- The cost field represents the total renewal cost
    NULL AS base_cost,
    NULL AS premium
FROM `web3-publicgoods.ens_temp2.raw_controller_events`  
WHERE topics[SAFE_OFFSET(0)] = '0x3da24c024582931cfaf8267d8ed24d13a82a8068d5bd337d30ec45cea4e506ae';