-- Load ENS labels from preimagedb.preimages.keccak256 into ens_temp.labels
-- This query converts text hashes to bytes and maps the columns appropriately

INSERT INTO `web3-publicgoods.ens_temp2.labels` (labelHash, label)
SELECT 
    -- Convert hex string hash to BYTES
    -- Assuming the hash column contains hex strings (with or without 0x prefix)
    CASE 
        WHEN STARTS_WITH(`hashed`, '0x') THEN FROM_HEX(SUBSTR(`hashed`, 3))
        ELSE FROM_HEX(`hashed`)
    END AS labelHash,
    -- Map text directly to label
    `text` AS label
FROM 
    `preimagedb.preimages.keccak256`
WHERE 
    -- Optional: Add any filtering conditions here
    -- For example, to exclude null or empty values:
    `hashed` IS NOT NULL 
    AND `text` IS NOT NULL
    AND LENGTH(`text`) > 0;