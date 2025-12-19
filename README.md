# ENS BigQuery Data Pipeline

This project manages ENS (Ethereum Name Service) related Google BigQuery data, providing comprehensive analytics on ENS domains, resolvers, registrations, and reverse records.

## 🚀 Quick Start

### Run the Complete Pipeline

```bash
# Run the smart hybrid incremental pipeline
./scripts/run_incremental_pipeline.sh --project-id=web3-publicgoods
```

**Cost:**
- First run: ~$30.75 (processes all historical data)
- Subsequent runs: ~$0.35 (incremental updates only)
- **98.9% cost reduction** after first run!

### Set up Automated Scheduling

```bash
# Set up daily scheduled queries with proper time intervals
./scripts/setup_daily_scheduled_queries.sh --project-id=web3-publicgoods
```

**Daily Scheduling System:**
- **Incremental extraction**: Raw events every 2 hours (already running)
- **Daily updates**: 14 separate queries with staggered execution times
  - 2:00-2:45 AM: Event decoding (5 queries, 10-min intervals)
  - 3:00-3:30 AM: State computation (4 queries, 5-10 min intervals)
  - 4:00-4:30 AM: Production tables (5 queries, 5-10 min intervals)
- **Individual queries**: Each DDL file runs independently (easier debugging)
- **Web UI monitoring** in BigQuery console
- **~$1.20/day** operating cost (96% reduction from $30.75!)

## 📋 Pipeline Overview

### Smart Hybrid Approach
- **Incremental stages**: Raw event extraction (expensive operations)
- **Full rebuild stages**: State computation and aggregation (cost-effective)
- **17 total stages**: From raw Ethereum logs to production analytics tables

### Key Output Tables
- `labels` - 134M+ keccak256 → plaintext mappings (enables name resolution)
- `registry` - 4M+ ENS domains with hierarchical names
- `resolvers` - 3.8M+ resolver records with text records and addresses  
- `reverse_records` - 421K+ validated reverse lookups
- `registration_periods` - 4.8M+ registration events with USD costs
- `resolutions` - Joined registry + resolver data

### Infrastructure Tables
- `_raw_*` - Raw event extractions from Ethereum logs
- `_decoded_*` - ABI-decoded event tables
- `_state_*` - Latest state computation tables
- `_agg_*` - Aggregation intermediate tables

## 🔧 Advanced Usage

### Validation (Free)
```bash
# Validate all SQL without running queries
./scripts/run_incremental_pipeline.sh --dry-run
```

### Force Full Rebuild
```bash  
# Option 1: Force full rebuild with incremental pipeline
./scripts/run_incremental_pipeline.sh --force-full

# Option 2: Use legacy full rebuild pipeline (guaranteed fresh start)
./scripts/run_pipeline.sh --project-id=web3-publicgoods
```

### Monitor Scheduled Pipeline
```bash
# Check scheduled query status
bq ls --transfer_config --transfer_location=us --max_results=10

# Monitor pipeline checkpoint
bq query "SELECT * FROM \`web3-publicgoods.ens._pipeline_checkpoint\`"

# Check table counts
bq query "SELECT COUNT(*) FROM \`web3-publicgoods.ens.registry\`"
bq query "SELECT COUNT(*) FROM \`web3-publicgoods.ens.resolvers\`" 
bq query "SELECT COUNT(*) FROM \`web3-publicgoods.ens.reverse_records\`"

# Web UI monitoring
echo "https://console.cloud.google.com/bigquery/scheduled-queries?project=web3-publicgoods"
```

## 📊 Data Sources

- **Primary**: `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.*`
- **ENS Labels**: `preimagedb.preimages.keccak256` (134M+ mappings)
- **Target Dataset**: `web3-publicgoods.ens.*`

## 🏗️ Architecture

### Pipeline Stages
1. **Checkpoint Table** - Incremental processing tracker
2. **Functions** - UDF functions (NAMEHASH, address extraction)
3. **Raw Events** - Extract ENS events from Ethereum logs (INCREMENTAL)
4. **Controller Events** - Decode NameRegistered/NameRenewed
5. **Base Registrar Events** - Decode NameMigrated events (INCREMENTAL)
6. **Resolver Events** - Decode all resolver events
7. **Historical Traces** - Legacy resolver setName calls
8. **Registry Events** - Decode NewOwner, Transfer events
9. **Resolver State** - Latest values per node
10. **Registry State** - Latest ownership per node
11. **Aggregated Resolver** - Combine text records and addresses
12. **Resolver Table** - Main resolver production table
13. **Aggregated Registry** - Registry analytics
14. **Registry Table** - Main registry production table
15. **Registration Periods** - Registration events with USD costs
16. **Reverse Records** - Validated reverse lookups
17. **Resolutions** - Combined registry + resolver data

### Smart Contracts Tracked
- ENS Registry (current + legacy)
- BaseRegistrarImplementation
- ETHRegistrarController  
- PublicResolver (all versions)
- ReverseRegistrar
- NameWrapper

## 🔒 Data Safety

The pipeline includes automatic backup capabilities:

```bash
# Backup current data before major changes
./scripts/backup_dataset.sh web3-publicgoods
```

## 📈 Cost Optimization

The pipeline uses a **smart hybrid approach**:
- **Expensive extraction** (stages 3 & 5): Incremental processing
- **Everything else**: Full rebuild (more cost-effective for smaller data)
- **Manual runs**: $0.35 incremental vs $30.75 full rebuild (98.9% savings)
- **Daily scheduled**: $1.20/day (includes all 14 production tables)

## 🛠️ Development

### File Structure
```
ddl/                          # SQL DDL files
├── create_functions.sql      # UDF functions
├── create_*_events.sql      # Event extraction and decoding  
├── create_state_*.sql       # Latest state computation
├── create_aggregated_*.sql  # Data aggregation
└── create_*_table.sql       # Production table creation

scripts/                      # Pipeline automation
├── run_incremental_pipeline.sh     # Main pipeline runner (manual)
├── run_pipeline.sh                 # Legacy full rebuild 
├── setup_daily_scheduled_queries.sh # Daily scheduled queries setup
└── backup_dataset.sh               # Data backup utility
```

## 📚 Documentation

- [ENS Deployments](https://docs.ens.domains/learn/deployments)
- [BigQuery Ethereum Analytics](https://mirror.xyz/nick.eth/INhEmxgxoyoa8kPZ3rjYNZXoyfGsReLgx42MdDvn4SM)
- [Custom Event Tables](https://mirror.xyz/nick.eth/KVal7tob7sqZSss27rrFlIpu6i91TJYJJvBzf53kwhQ)

---

**Ready to get started?** Run: `./scripts/run_incremental_pipeline.sh --project-id=web3-publicgoods`

## QA

- [x] Daily registration & renewal (*.view_daily_summary) counts match with Dune dashboard https://dune.com/queries/6535/12977
- [ ] Number of Active .eth names
- [ ] Number of Active reverse names
- [ ] Number of Unique Addresses


## Open itesm

- check resolver events quality
- check registry events quality
- check `reverse_record` quality
- check `resolutins` quality
- check `resolvers` quality
- Add OG ENS data
- Add clustering using 1000 clubs, chinese, arabic, etc
