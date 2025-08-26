-- Create resolutions table by joining registry and resolvers
-- This provides complete forward resolution: name -> owner -> resolver -> addresses/content

CREATE OR REPLACE TABLE `web3-publicgoods.ens.resolutions` AS
SELECT 
    r.node,
    r.name,
    -- Get the resolved address from the resolver
    res.addr,
    -- Get text records as JSON-compatible string for backward compatibility
    CASE 
        WHEN ARRAY_LENGTH(COALESCE(res.text_records, [])) > 0 THEN
            CONCAT('[',
                STRING_AGG(
                    CONCAT('{"key":"', tr.key, '","value":"', IFNULL(tr.value, ''), '"}'),
                    ','
                ), 
            ']')
        ELSE '[]'
    END AS texts,
    -- Get multi-chain addresses  
    COALESCE(res.addresses, '{}') AS addresses
FROM `web3-publicgoods.ens.registry` r
-- Join with resolvers to get resolution data
LEFT JOIN `web3-publicgoods.ens.resolvers` res
    ON r.node = res.node 
    AND r.resolver = res.address
-- Unnest text records for JSON building
LEFT JOIN UNNEST(COALESCE(res.text_records, [])) AS tr
WHERE (
    -- Include if it has an address resolution
    res.addr IS NOT NULL 
    -- Or if it has text records
    OR ARRAY_LENGTH(COALESCE(res.text_records, [])) > 0
    -- Or if it has multi-chain addresses
    OR COALESCE(res.addresses, '{}') != '{}'
)
GROUP BY r.node, r.name, res.addr, res.addresses, res.text_records;