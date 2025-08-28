# ENS BigQuery Data Pipeline Documentation

## Overview

This document describes the ENS (Ethereum Name Service) BigQuery data pipeline, including table relationships, data transformations, and derivation logic. The pipeline processes raw blockchain data from Google's public Ethereum dataset into structured ENS-specific tables for analysis and querying.

## True Data Sources

### Primary Source: `bigquery-public-data.goog_blockchain_ethereum_mainnet_us`

All ENS data ultimately derives from Google's public Ethereum BigQuery dataset:

1. **`bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`** 🌐 *Ultimate Source*
   - **Content**: All Ethereum event logs from every contract
   - **ENS Filtering**: Filtered by ENS contract addresses:
     - `0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85` (ENS Base Registrar - 13.5M events)
     - `0x253553366da8546fc250f225fe3d25d0c782303b` (ENS Controller - 1.2M events)  
     - `0x314159265dd8dbb310642f98f50c066173c1259b` (ENS Registry - 1.1M events)

2. **`bigquery-public-data.goog_blockchain_ethereum_mainnet_us.traces`** 🌐 *Ultimate Source*
   - **Content**: All Ethereum transaction traces
   - **ENS Filtering**: Filtered by ENS contract addresses for detailed execution data

3. **`bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions`** 🌐 *Ultimate Source*
   - **Content**: All Ethereum transactions
   - **Usage**: Transaction metadata and gas price information

### External Reference Data

4. **`preimagedb.preimages.keccak256`** 🌐 *External Source*
   - **Content**: Known keccak256 preimages (label mappings)
   - **Usage**: Maps label hashes to human-readable names
   - **Provider**: Community-maintained preimage database

## Dataset Structure

### Primary Datasets
- **`names`**: Contains ENS name resolution and registry data (derived from public data)
- **`registrations`**: Contains ENS registration and renewal events data (derived from public data)
- **`ens_temp`**: Temporary staging area for new table structures

## Table Analysis and Dependencies

### Names Dataset Tables

#### Extracted Tables (From Public Sources)

1. **`controller_events`** 📊 *Extracted Table*
   - **True Source**: `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs`
   - **Extraction Logic**: `WHERE address IN ('0x253553366da8546fc250f225fe3d25d0c782303b', ...)`
   - **Content**: Raw Ethereum event logs from ENS controller contracts
   - **Key Fields**: transaction_hash, block_number, block_timestamp, address, data, topics
   - **Purpose**: Filtered raw events for ENS controllers

2. **`controller_traces`** 📊 *Extracted Table*
   - **True Source**: `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.traces`
   - **Extraction Logic**: `WHERE to_address IN ('0x253553366da8546fc250f225fe3d25d0c782303b', ...)`
   - **Content**: Ethereum transaction traces for ENS controller calls
   - **Purpose**: Detailed execution traces for controller interactions

#### Decoded Tables (From Extracted Data)

3. **`ETHRegistrarController4_event_NameRegistered`** 🔧 *Decoded Table*
   - **Source**: `controller_events` (filtered from public logs)
   - **Decoding Logic**: ABI decoding of NameRegistered event signature
   - **Event Signature**: `0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27`
   - **Key Fields**: name, label, owner, baseCost, premium, expires
   - **Content**: Parsed NameRegistered events from ETHRegistrarController4

4. **`ETHRegistrarController4_event_NameRenewed`** 🔧 *Decoded Table*
   - **Source**: `controller_events` (filtered from public logs)
   - **Decoding Logic**: ABI decoding of NameRenewed event signature
   - **Content**: Parsed NameRenewed events
   - **Key Fields**: Similar to NameRegistered with renewal-specific data

5. **`ETHRegistrarController4_event_NameRenewed_fixed`** 🔧 *Corrected Table*
   - **Source**: `ETHRegistrarController4_event_NameRenewed`
   - **Content**: Fixed/corrected version of NameRenewed events
   - **Purpose**: Data quality improvements over the base NameRenewed table

#### Reference Tables

6. **`dictionary`** 📚 *Reference Table*
   - **Source**: Manually curated or external word lists
   - **Content**: Dictionary of known ENS names for validation
   - **Key Fields**: name
   - **Purpose**: Label resolution and name validation

#### Processed/Derived Tables

7. **`names`** 🔄 *Derived Table*
   - **Sources**: 
     - `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs` (registry events)
     - `controller_events` and decoded event tables
   - **Derivation Logic**: 
     ```sql
     -- Simplified example
     SELECT DISTINCT 
       latest_resolver as resolver,
       node,
       COALESCE(label_from_preimages, node_hash) as name
     FROM registry_events r
     LEFT JOIN preimage_labels p ON r.labelhash = p.labelhash
     WHERE r.event_timestamp = (SELECT MAX(event_timestamp) FROM registry_events r2 WHERE r2.node = r.node)
     ```
   - **Content**: Current state of ENS name-to-resolver mappings
   - **Key Fields**: resolver, node, name
   - **Logic**: Latest resolver state for each ENS node

8. **`addrs`** 🔄 *Derived Table*
   - **Type**: Address resolution data
   - **Content**: Node-to-address mappings from resolvers
   - **Key Fields**: resolver, node, addr
   - **Derivation**: Extracted from resolver contract events
   - **Logic**: Current address resolution for each node

9. **`resolvers`** 🔄 *Derived Table*
   - **Type**: Resolver contract data
   - **Content**: Detailed resolver information and capabilities
   - **Derivation**: Aggregated from resolver contract interactions

10. **`reverse_records`** 🔄 *Derived Table*
    - **Type**: Reverse resolution data
    - **Content**: Address-to-name reverse lookups
    - **Derivation**: Computed from forward resolution data and reverse registrar events

#### Views (Virtual Tables)

11. **`resolved_addrs`** 👁️ *View*
    - **Type**: Materialized view
    - **Content**: Clean node-to-address mappings
    - **Key Fields**: node, addr
    - **Derivation**: `SELECT node, addr FROM addrs WHERE addr != '0x0000000000000000000000000000000000000000'`
    - **Logic**: Filters out null/zero addresses from the addrs table

### Registrations Dataset Tables

#### Extracted Tables

1. **`contract_interactions`** 📊 *Extracted Table*
   - **True Source**: `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions`
   - **Extraction Logic**: `WHERE to_address IN (ENS_CONTRACT_ADDRESSES)`
   - **Content**: All transaction interactions with ENS contracts
   - **Purpose**: Source data for registration cost and gas analysis

#### Derived Tables

2. **`registration_periods`** 🔄 *Derived Table*
   - **Sources**: 
     - `ETHRegistrarController4_event_NameRegistered`
     - `ETHRegistrarController4_event_NameRenewed`
     - `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions` (for ETH prices)
   - **Derivation Logic**:
     ```sql
     -- Simplified example
     SELECT 
       labelhash,
       label,
       event_timestamp,
       event_timestamp as start_time,
       TIMESTAMP_SECONDS(expires) as end_time,
       baseCost + premium as cost,
       eth_price_at_timestamp as ether_price,
       'registered' as event
     FROM ETHRegistrarController4_event_NameRegistered nr
     LEFT JOIN eth_prices ep ON DATE(nr.block_timestamp) = ep.date
     UNION ALL
     SELECT ... FROM ETHRegistrarController4_event_NameRenewed
     ```
   - **Content**: Registration and renewal periods with costs
   - **Key Fields**: labelhash, label, event_timestamp, start_time, end_time, cost, ether_price, event

#### Views

3. **`registration_periods_view`** 👁️ *View*
   - **Type**: Enhanced view of registration periods
   - **Content**: Registration periods with additional computed fields
   - **Key Fields**: transaction_hash, labelhash, label, event_timestamp, log_index, start_time, end_time, cost, ether_price, event
   - **Derivation**: Joins registration_periods with transaction data

4. **`Registraion periods`** 👁️ *View* (Note: Typo in name)
   - **Type**: Duplicate/alternative view
   - **Content**: Similar to registration_periods_view
   - **Status**: Appears to be a duplicate with a typo in the name

## Data Flow and Transformation Logic

### 1. Data Extraction from Public Sources
```
bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs 
├── WHERE address = '0x253553366da8546fc250f225fe3d25d0c782303b' → controller_events
├── WHERE address = '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85' → registrar_events  
└── WHERE address = '0x314159265dd8dbb310642f98f50c066173c1259b' → registry_events

bigquery-public-data.goog_blockchain_ethereum_mainnet_us.traces
└── WHERE to_address IN (ENS_ADDRESSES) → controller_traces

bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions  
└── WHERE to_address IN (ENS_ADDRESSES) → contract_interactions

preimagedb.preimages.keccak256 → labels (label hash mappings)
```

### 2. Event Decoding (ABI Parsing)
```
controller_events 
├── WHERE topics[0] = '0x69e37f151eb98a09618ddaa80c8cfaf1ce5996867c489f45b555b412271ebf27'
│   └→ ETHRegistrarController4_event_NameRegistered
└── WHERE topics[0] = '0x[NameRenewed signature]'
    └→ ETHRegistrarController4_event_NameRenewed
        └→ ETHRegistrarController4_event_NameRenewed_fixed (manual corrections)
```

### 3. State Aggregation (Latest State Logic)
```
Registry Events + Label Mappings → names (current resolver state)
Resolver Events + Contract Calls → addrs (address resolutions)  
Multiple Resolver Sources → resolvers (resolver capabilities)
```

### 4. Resolution Logic
```
names + addrs → resolved_addrs (active resolutions only)
Forward Resolution + Reverse Registrar → reverse_records (computed reverse lookups)
```

### 5. Registration Analysis & Enrichment
```
NameRegistered + NameRenewed Events + ETH Price Data → registration_periods
registration_periods + Transaction Metadata → registration_periods_view
```

### 6. Label Resolution Enhancement
```
preimagedb.preimages.keccak256 
└── FROM_HEX(hashed) as labelHash, text as label → ens_temp.labels
    └→ JOIN with other tables for human-readable names
```

## Key Transformation Patterns

### 1. State Aggregation
- **Pattern**: Latest state wins
- **Applied to**: `names`, `addrs`, `resolvers`
- **Logic**: For each node/resolver, keep only the most recent state

### 2. Event Decoding
- **Pattern**: Raw logs → Structured events
- **Applied to**: All `*_event_*` tables
- **Logic**: Parse ABI-encoded event data into typed columns

### 3. Cross-Reference Enrichment
- **Pattern**: Join with reference data
- **Applied to**: Label resolution using `dictionary`
- **Logic**: Replace label hashes with human-readable names where known

### 4. Computed Metrics
- **Pattern**: Derive business metrics
- **Applied to**: `registration_periods` (cost calculations, duration)
- **Logic**: Calculate registration costs, periods, and renewal patterns

### 5. Data Quality Fixes
- **Pattern**: Corrected versions of base tables
- **Applied to**: `ETHRegistrarController4_event_NameRenewed_fixed`
- **Logic**: Manual corrections for data quality issues

## Recommended ens_temp Schema Alignment

Based on the existing pipeline, the `ens_temp` tables should align with:

```sql
-- Align with names.names
CREATE TABLE ens_temp.registry AS names
-- Align with names.addrs  
CREATE TABLE ens_temp.resolvers AS addrs + resolver details
-- Align with names.resolved_addrs
CREATE TABLE ens_temp.resolutions AS resolved_addrs + enrichment
-- Align with registrations.registration_periods
CREATE TABLE ens_temp.registration_periods AS registration_periods
-- New label mapping table
CREATE TABLE ens_temp.labels (labelHash, label) -- ✅ Already created
```

## Complete Data Lineage Summary

```
🌐 ULTIMATE SOURCES (Google Public Data + External)
├── bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs (16M+ ENS events)
├── bigquery-public-data.goog_blockchain_ethereum_mainnet_us.traces  
├── bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions
└── preimagedb.preimages.keccak256 (134M+ label mappings)
    │
    ├── 📊 EXTRACTION LAYER (Contract Address Filtering)
    │   ├── controller_events (1.2M events from Controller)
    │   ├── controller_traces (Controller execution traces)
    │   ├── contract_interactions (All ENS transactions)
    │   └── labels ✅ (134M preimage mappings)
    │
    ├── 🔧 DECODING LAYER (ABI Event Parsing)
    │   ├── ETHRegistrarController4_event_NameRegistered
    │   ├── ETHRegistrarController4_event_NameRenewed
    │   └── ETHRegistrarController4_event_NameRenewed_fixed
    │
    ├── 🔄 STATE COMPUTATION LAYER (Latest State Logic)
    │   ├── names (Current resolver mappings)
    │   ├── addrs (Current address resolutions)
    │   ├── resolvers (Resolver capabilities)
    │   ├── reverse_records (Reverse lookups)
    │   └── registration_periods (Registration analytics)
    │
    ├── 👁️ VIEW LAYER (Query Optimization)
    │   ├── resolved_addrs (Non-zero addresses only)
    │   ├── registration_periods_view (Enhanced with metadata)
    │   └── "Registraion periods" (Duplicate view)
    │
    └── 🎯 ENS_TEMP TARGET SCHEMA (New Implementation)
        ├── labels ✅ (Implemented - 134M records loaded)
        ├── registry (Planned - align with names)  
        ├── resolvers (Planned - align with addrs + resolver details)
        ├── resolutions (Planned - align with resolved_addrs + enrichment)
        ├── reverse_records (Planned - align with existing)
        └── registration_periods (Planned - align with existing)
```

## ENS Contract Addresses (Key Filters)
- **0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85**: ENS Base Registrar (13.5M events)
- **0x253553366da8546fc250f225fe3d25d0c782303b**: ENS Controller (1.2M events)  
- **0x314159265dd8dbb310642f98f50c066173c1259b**: ENS Registry (1.1M events)

## Legend
- 🌐 **Ultimate Source**: Google's public blockchain data or external APIs
- 📊 **Extracted Table**: Filtered from public sources by contract address
- 🔧 **Decoded Table**: ABI-decoded events from raw logs
- 🔄 **Derived Table**: Computed/aggregated with business logic
- 👁️ **View**: Virtual table with filtering/joining logic  
- ✅ **Implemented**: Already exists in ens_temp
- 🎯 **Target Schema**: Planned implementation in ens_temp

## Key Data Transformation Pipeline

**Extract** (Contract Filtering) → **Decode** (ABI Parsing) → **Aggregate** (State Logic) → **View** (Query Optimization) → **Target** (New Schema)

This follows Nick's blog approach of processing Google's public Ethereum data through ENS-specific transformations to create queryable, analysis-ready datasets.