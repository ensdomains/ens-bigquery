# ENS BigQuery Table Documentation

## Table: labels
Stores known keccak256 preimages for ENS labels.

| Column | Type | Description |
|--------|------|-------------|
| labelHash | BYTES | The keccak256 hash of the label |
| label | STRING | The human-readable ENS label |

## Table: registry
Contains information derived from the main ENS registry contract.

| Column | Type | Description |
|--------|------|-------------| 
| node | BYTES | The ENS node hash |
| labelHash | BYTES | The keccak256 hash of the label |
| parentNode | BYTES | The parent node hash |
| owner | STRING | The Ethereum address of the owner |
| resolver | STRING | The Ethereum address of the resolver contract |
| name | STRING | Human-readable name. Unknown labels are replaced by node hashes in square brackets |

## Table: resolvers
Contains information from any contract that emits resolver events.

| Column | Type | Description |
|--------|------|-------------|
| address | STRING | Resolver contract address |
| node | STRING | The ENS node hash associated with the resolver |
| addr | STRING | The resolved Ethereum address |
| text_records | ARRAY<STRUCT<key STRING, value STRING>> | Array of text record key-value pairs for filtering and querying |
| texts | STRING | CSV of text record keys (backward compatibility) |
| addresses | STRING | JSON mapping of chain IDs and cointypes to addresses |
| contenthash | STRING | The raw ABI-encoded content hash for the node |
| raw_contenthash | STRING | The extracted contenthash after ABI decoding |
| decoded_contenthash | STRING | Human-readable decoded contenthash (e.g., IPFS CID, Arweave hash, .onion address) |
| content_type | STRING | Content type codec (e.g., 'ipfs', 'ipns', 'swarm', 'arweave', 'skynet', 'onion', 'onion3') |
| reverseName | STRING | Name for reverse resolvers (not the name for this node) |

### Text Records Structure
The `text_records` field stores text records as an array of structs with `key` and `value` fields. This structure enables powerful filtering and querying capabilities:

**Example structure:**
```json
[
  {"key": "com.twitter", "value": "vitalik"},
  {"key": "description", "value": "Ethereum co-founder"},
  {"key": "url", "value": "https://vitalik.ca"}
]
```

**Common query patterns:**
- Filter by specific key: `WHERE EXISTS (SELECT 1 FROM UNNEST(text_records) AS t WHERE t.key = 'com.twitter')`
- Filter by key-value pair: `WHERE EXISTS (SELECT 1 FROM UNNEST(text_records) AS t WHERE t.key = 'com.twitter' AND t.value = 'vitalik')`
- Extract specific value: `(SELECT value FROM UNNEST(text_records) WHERE key = 'com.twitter') AS twitter_handle`

See `sample_text_record_queries.sql` for comprehensive examples.

## Table: resolutions
A join of the Registry and Resolvers tables for complete forward resolution.

| Column | Type | Description |
|--------|------|-------------|
| node | BYTES | The ENS node hash |
| name | STRING | Human-readable name. Unknown labels are replaced by node hashes in square brackets |
| addr | STRING | The resolved Ethereum address |
| texts | STRING | An array of text records (stored as JSON string) |
| addresses | STRING | An array of addresses for different chains (stored as JSON string) |

## Table: reverse_records
Stores reverse records generated from resolutions.

| Column | Type | Description |
|--------|------|-------------|
| name | STRING | The ENS name |
| address | STRING | The corresponding Ethereum address |

## Table: registration_periods
Contains computed data for name registration periods with USD cost derivations.

| Column | Type | Description |
|--------|------|-------------|
| labelhash | STRING | The hash of the label |
| label | STRING | The human-readable ENS label |
| event_timestamp | TIMESTAMP | Time at which the registration/renewal occurred |
| start_time | TIMESTAMP | Time at which this registration period begins |
| end_time | TIMESTAMP | Time at which this registration period ends |
| cost | FLOAT64 | Cost in ETH for this registration period |
| event | STRING | The type of event: ['registered', 'renewed', 'migrated'] |
| duration_years | FLOAT64 | Registration duration in years (calculated from start_time to end_time) |
| base_cost_usd_per_year | FLOAT64 | Base cost per year in USD: $5 (5+ chars), $160 (4 chars), $640 (3 chars) |
| base_cost_usd | FLOAT64 | Total base cost in USD (duration_years × base_cost_usd_per_year) |
| premium | FLOAT64 | Premium cost in ETH for this registration period |
| eth_usd_rate | FLOAT64 | ETH-USD exchange rate from Uniswap USDC-ETH pair at registration time |
| premium_usd | FLOAT64 | Premium cost in USD (premium × eth_usd_rate) |

### USD Cost Methodology

The table uses external Uniswap price data to calculate accurate USD costs for ENS registrations:

**Base Pricing (per year):**
- 3 characters: $640/year
- 4 characters: $160/year  
- 5+ characters: $5/year

**Data Sources:**
- ETH-USD rates: `blockchain-etl.ethereum_uniswap.UniswapV2Pair_event_Sync` (USDC-ETH pair: 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc)
- Controller v4: Directly provides `baseCost` and `premium` fields
- Controller v1-v3: Only provides combined `cost`, premium derived as: `cost - (theoretical_base_cost_usd / eth_usd_rate)`

**Calculations:**
- `base_cost_usd = base_cost_usd_per_year × duration_years`
- `eth_usd_rate = 1e12 × USDC_reserve / ETH_reserve` (from Uniswap)
- `premium = total_cost_eth - theoretical_base_cost_eth` (for v1-v3)
- `premium_usd = premium × eth_usd_rate`

This methodology provides accurate historical USD costs using real-time market prices from Uniswap, spanning from ENS permanent registrar launch (May 2019) to present.