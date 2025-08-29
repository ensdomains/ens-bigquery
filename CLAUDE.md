This project is to manage various ens related google bigquery data

## IMPORTANT

You can only run bq command for query purpose. For creating/inserting data, please just show the command so that I can run by myself


## Documentation Resources

- [ List of deployed addresses](https://docs.ens.domains/learn/deployments)
- [Ethereum analytics with BigQuery](https://mirror.xyz/nick.eth/INhEmxgxoyoa8kPZ3rjYNZXoyfGsReLgx42MdDvn4SM)
- [Custom Event Tables with BigQuery](https://mirror.xyz/nick.eth/KVal7tob7sqZSss27rrFlIpu6i91TJYJJvBzf53kwhQ)
## Data Sources
- **Primary Source**: `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.*` (Google's public Ethereum dataset)
  - `logs`: All Ethereum event logs from every contract
  - `traces`: All Ethereum transaction traces
  - `transactions`: All Ethereum transactions
- **ENS Labels**: `preimagedb.preimages.keccak256` (134M+ label mappings)
- **Legacy Schema**: `ens-manager.names` and `ens-manager.registrations`
- **Target Schema**: `web3-publicgoods.ens.*` following ddl/table_documentation.md

## Target Schema Pipeline Architecture

## List of ENS related smart contracts

  - registry
  - base_registrar
  - eth_registrar_controller
  - dns_registrar
  - reverse_registrar
  - name_wrapper
  - public_resolver
  - universal_resolver

## BigQuery Reserved Keywords Mapping

When creating event tables, the following column names were mapped to avoid BigQuery reserved keywords:

| Original Event Field | BigQuery Column Name | Reason |
|---------------------|---------------------|---------|
| `hash` | `content_hash` | `HASH` is reserved keyword |
| `key` | `text_key` | `KEY` is reserved keyword |
| `value` | `text_value` | `VALUE` is reserved keyword |
| `name` | `domain_name` | `NAME` is reserved keyword |
| `from` | `from_address` | `FROM` is reserved keyword |
| `to` | `to_address` | `TO` is reserved keyword |

**Note**: These mappings apply to all event tables in the `ens_decoded_*` schema to ensure consistency and avoid SQL syntax errors.

## Table hierarchy

```
🌐 SOURCE LAYER: bigquery-public-data.goog_blockchain_ethereum_mainnet_us.*
├── logs (Raw event logs)
├── traces (Transaction execution traces)
└── transactions (Transaction metadata)
    │
    ├── 📊 EXTRACTION LAYER: Contract-filtered raw data
    │   ├── raw_resolver_events
    │   ├── raw_registry_events  
    │   ├── raw_registrar_events
    │   ├── raw_controller_events
    │   ├── raw_base_registrar_events
    │   ├── raw_name_wrapper_events
    │   └── historical_reverse_traces
    │
    ├── 🔧 DECODING LAYER: ABI-decoded events
    │   ├── RESOLVER EVENTS:
    │   │   ├── decoded_resolver_AddrChanged
    │   │   ├── decoded_resolver_AddressChanged  
    │   │   ├── decoded_resolver_TextChanged_v3
    │   │   ├── decoded_resolver_TextChanged_v4
    │   │   ├── decoded_resolver_ContenthashChanged
    │   │   ├── decoded_resolver_NameChanged
    │   │   └── decoded_resolver_* (11 event types total)
    │   │
    │   ├── CONTROLLER EVENTS:
    │   │   ├── decoded_controller_NameRegistered
    │   │   └── decoded_controller_NameRenewed
    │   │
    │   ├── BASE REGISTRAR EVENTS:
    │   │   ├── decoded_base_registrar_NameRegistered
    │   │   ├── decoded_base_registrar_NameRenewed
    │   │   └── decoded_base_registrar_NameMigrated
    │   │
    │   └── REGISTRY EVENTS:
    │       ├── decoded_registry_NewOwner
    │       ├── decoded_registry_Transfer
    │       └── decoded_registry_NewResolver
    │
    ├── 🔄 STATE LAYER: Latest values per node
    │   ├── RESOLVER STATE:
    │   │   ├── state_resolver_eth_addresses
    │   │   ├── state_resolver_contenthashes
    │   │   ├── state_resolver_reverse_names (combines events + traces)
    │   │   ├── state_resolver_pubkeys
    │   │   ├── state_resolver_abi
    │   │   ├── state_resolver_interfaces
    │   │   └── state_resolver_authorizations
    │   │
    │   └── REGISTRY STATE:
    │       ├── state_registry_owners (latest owner per node)
    │       ├── state_registry_resolvers (latest resolver per node)
    │       └── state_registry_labels (first label per node)
    │
    ├── 📊 AGGREGATION LAYER: Collections and analytics
    │   ├── RESOLVER AGGREGATION:
    │   │   ├── agg_resolver_text_records (array of key-value structs)
    │   │   ├── agg_resolver_addresses (multi-chain addresses)
    │   │   ├── agg_resolver_texts (deduplicated text records)
    │   │   └── agg_resolver_activity (event statistics)
    │   │
    │   └── REGISTRY AGGREGATION:
    │       ├── agg_registry_hierarchy (parent-child relationships with keccak256)
    │       └── agg_registry_activity (ownership and resolver statistics)
    │
    └── 🎯 TARGET LAYER: Final production tables
        ├── labels (134M+ keccak256 preimages from preimagedb)
        ├── resolvers (main table with text_records array)
        ├── resolvers_clustered (performance-optimized)
        ├── registry (4.06M nodes with hierarchical names)
        ├── registration_periods (with accurate USD pricing via Uniswap)
        ├── reverse_records (validated reverse lookups, ~500k records)
        ├── reverse_records_unvalidated (debugging/unvalidated)
        └── resolutions (joined registry + resolvers)
```

## Production Pipeline (16 DDL files in order)
1. `create_functions.sql` - All UDF functions (NAMEHASH, DECODE_SET_NAME, etc.) → Functions
2. `create_ens_raw_events.sql` - Extract raw events from Ethereum logs → `raw_*` tables
3. `create_controller_event_tables.sql` - Decode NameRegistered/NameRenewed events → `decoded_controller_*`
4. `create_base_registrar_events.sql` - Decode NameMigrated events → `decoded_base_registrar_*`
5. `create_resolver_event_tables.sql` - Decode all resolver events → `decoded_resolver_*`
6. `create_historical_reverse_traces.sql` - Extract setName calls from old resolvers → `historical_reverse_traces`
7. `create_registry_event_tables.sql` - Decode registry events (NewOwner, Transfer, etc.) → `decoded_registry_*`
8. `create_state_resolver.sql` - Compute latest state (events + traces) → `state_resolver_*`
9. `create_state_registry.sql` - Compute latest registry state → `state_registry_*`
10. `create_aggregated_resolver.sql` - Aggregate text records and addresses → `agg_resolver_*`
11. `create_resolver_table.sql` - Combine into main resolver table → `resolvers`
12. `create_aggregated_registry.sql` - Aggregate registry data → `agg_registry_*`
13. `create_registry_table.sql` - Create registry table → `registry`
14. `create_registration_periods_table.sql` - Registration periods with USD costs → `registration_periods`
15. `create_reverse_records_table.sql` - Generate reverse records → `reverse_records`
16. `create_resolutions_table.sql` - Join registry + resolvers → `resolutions`

**Run command:** `./scripts/run_pipeline.sh`
**Target dataset:** `web3-publicgoods.ens.*`

## Historical Traces Integration

Some of the earlier version of reverse record didn't emit events. To supplement the data, we extract historical `setName()` function calls from transaction traces. Old resolver contracts (pre-2019) didn't always emit `NameChanged` events properly.

### Key Components:
- **DECODE_SET_NAME function**: Decodes `setName(bytes32,string)` calls from transaction input data
- **historical_reverse_traces table**: Stores extracted setName calls from old resolvers (0x5fbb..., 0xa2c1...)
- **state_resolver_reverse_names**: Combines NameChanged events + historical traces using UNION ALL
- **Forward resolution validation**: Ensures names resolve back to correct addresses

### Old Resolver Addresses with Event Issues:
- `0x5fbb459c49bb06083c33109fa4f14810ec2cf358` - Old resolver with event emission issues
- `0xa2c122be93b0074270ebee7f6b7292c7deb45047` - Another problematic old resolver

This integration runs as part of the main pipeline (stage 6) and supplements event data with direct function call traces.

========================
BIGQUERY CODE SNIPPETS
========================
TITLE: BigQuery Quickstarts
DESCRIPTION: Guides for getting started with BigQuery using different tools. Includes querying public data and loading data.

SOURCE: https://cloud.google.com/bigquery/docs/best-practices-performance-overview

LANGUAGE: APIDOC
CODE:
```
BigQuery Quickstarts:

Cloud Console Quickstarts:
  Query public data: /bigquery/docs/quickstarts/query-public-dataset-console
  Load and query data: /bigquery/docs/quickstarts/load-data-console

Command-line tool (bq) Quickstarts:
  Query public data: /bigquery/docs/quickstarts/query-public-dataset-bq
  Load and query data: /bigquery/docs/quickstarts/load-data-bq

Client Libraries Quickstart:
  Try the client libraries: /bigquery/docs/quickstarts/quickstart-client-libraries
```

----------------------------------------

TITLE: BigQuery Quickstarts
DESCRIPTION: Guides for getting started with BigQuery using different tools. Includes querying public data and loading data.

SOURCE: https://cloud.google.com/bigquery/docs/best-practices-storage

LANGUAGE: APIDOC
CODE:
```
BigQuery Quickstarts:

Cloud Console Quickstarts:
  Query public data: /bigquery/docs/quickstarts/query-public-dataset-console
  Load and query data: /bigquery/docs/quickstarts/load-data-console

Command-line tool (bq) Quickstarts:
  Query public data: /bigquery/docs/quickstarts/query-public-dataset-bq
  Load and query data: /bigquery/docs/quickstarts/load-data-bq

Client Libraries Quickstart:
  Try the client libraries: /bigquery/docs/quickstarts/quickstart-client-libraries
```

----------------------------------------

TITLE: BigQuery Data Transfer Service Quickstart
DESCRIPTION: Using the Data Transfer Service to load and transfer data into BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/transfer-service-overview

LANGUAGE: APIDOC
CODE:
```
Data Transfer Service: https://cloud.google.com/bigquery-transfer/
Getting Started: https://cloud.google.com/bigquery-transfer/docs/introduction
Quickstart: https://cloud.google.com/bigquery-transfer/docs/quickstart

Support for transferring data from:
  - SaaS applications (AdWords, YouTube, etc.)
  - External cloud storage (Amazon S3)
  - Data warehouses (Teradata, Redshift)
  - Google services (Google Ads, Google Play)

bq mk --transfer_config command to create scheduled transfers
```

----------------------------------------

TITLE: BigQuery SQL best practices
DESCRIPTION: Best practices for writing SQL in BigQuery, including using APPROX functions for performance optimization.

SOURCE: https://cloud.google.com/bigquery/docs/best-practices-performance-overview

LANGUAGE: SQL
CODE:
```sql
-- Using approximate aggregation functions for better performance
SELECT APPROX_COUNT_DISTINCT(user_id) AS unique_users
FROM `project.dataset.table`;

-- Instead of exact count:
-- SELECT COUNT(DISTINCT user_id) AS unique_users

-- Use APPROX_QUANTILES for percentiles
SELECT APPROX_QUANTILES(value, 100)[OFFSET(50)] AS median
FROM `project.dataset.table`;

-- Use APPROX_TOP_COUNT for top N
SELECT APPROX_TOP_COUNT(category, 10) AS top_categories
FROM `project.dataset.table`;
```

----------------------------------------

TITLE: BigQuery clustering and partitioning
DESCRIPTION: Best practices for table partitioning and clustering to optimize query performance and costs.

SOURCE: https://cloud.google.com/bigquery/docs/best-practices-storage

LANGUAGE: SQL
CODE:
```sql
-- Create a partitioned and clustered table
CREATE TABLE `project.dataset.events_clustered`
PARTITION BY DATE(timestamp)
CLUSTER BY user_id, event_type
AS
SELECT * FROM `project.dataset.events`;

-- Query that benefits from partitioning and clustering
SELECT user_id, COUNT(*) as event_count
FROM `project.dataset.events_clustered`
WHERE DATE(timestamp) = '2023-01-01'
  AND user_id = 'user123'
GROUP BY user_id;
```

----------------------------------------

TITLE: BigQuery DML best practices
DESCRIPTION: Best practices for using DML statements (INSERT, UPDATE, DELETE, MERGE) in BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/best-practices-performance-overview

LANGUAGE: SQL
CODE:
```sql
-- Use MERGE for upserts instead of separate UPDATE/INSERT
MERGE `project.dataset.target` T
USING `project.dataset.source` S
ON T.id = S.id
WHEN MATCHED THEN
  UPDATE SET T.value = S.value, T.updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (id, value, created_at) VALUES (S.id, S.value, CURRENT_TIMESTAMP());

-- Batch deletes with partition pruning
DELETE FROM `project.dataset.events`
WHERE DATE(timestamp) = '2023-01-01'
  AND user_id IN (SELECT user_id FROM `project.dataset.inactive_users`);
```

----------------------------------------

TITLE: BigQuery array and struct functions
DESCRIPTION: Working with arrays and structs in BigQuery for complex data structures.

SOURCE: https://cloud.google.com/bigquery/docs/reference/standard-sql/arrays

LANGUAGE: SQL
CODE:
```sql
-- Working with arrays
SELECT 
  user_id,
  ARRAY_AGG(DISTINCT product_id) AS purchased_products,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT product_id)) AS unique_products_count
FROM `project.dataset.purchases`
GROUP BY user_id;

-- Working with structs
SELECT
  user_id,
  STRUCT(
    name AS display_name,
    email AS contact_email,
    ARRAY_AGG(order_id) AS order_history
  ) AS user_info
FROM `project.dataset.users` u
LEFT JOIN `project.dataset.orders` o USING(user_id)
GROUP BY user_id, name, email;

-- Unnesting arrays
SELECT 
  user_id,
  product
FROM `project.dataset.user_products`,
UNNEST(products) AS product;
```

----------------------------------------

TITLE: BigQuery scripting and procedures
DESCRIPTION: Using scripting and stored procedures in BigQuery for complex logic.

SOURCE: https://cloud.google.com/bigquery/docs/reference/standard-sql/scripting

LANGUAGE: SQL
CODE:
```sql
-- Create a stored procedure
CREATE OR REPLACE PROCEDURE `project.dataset.update_user_stats`()
BEGIN
  DECLARE row_count INT64;
  
  -- Update user statistics
  UPDATE `project.dataset.user_stats` 
  SET last_calculated = CURRENT_TIMESTAMP()
  WHERE TRUE;
  
  SET row_count = @@row_count;
  
  -- Log the update
  INSERT INTO `project.dataset.audit_log` (action, row_count, timestamp)
  VALUES ('update_user_stats', row_count, CURRENT_TIMESTAMP());
  
  SELECT CONCAT('Updated ', CAST(row_count AS STRING), ' rows') AS result;
END;

-- Call the procedure
CALL `project.dataset.update_user_stats`();
```

----------------------------------------

TITLE: BigQuery window functions
DESCRIPTION: Using window functions for advanced analytics in BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/reference/standard-sql/window-function-calls

LANGUAGE: SQL
CODE:
```sql
-- Ranking and row numbering
SELECT 
  user_id,
  purchase_date,
  amount,
  ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY purchase_date) AS purchase_number,
  RANK() OVER (ORDER BY amount DESC) AS amount_rank,
  PERCENT_RANK() OVER (ORDER BY amount) AS amount_percentile
FROM `project.dataset.purchases`;

-- Moving averages and cumulative sums
SELECT 
  date,
  sales,
  AVG(sales) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7days,
  SUM(sales) OVER (ORDER BY date) AS cumulative_sales
FROM `project.dataset.daily_sales`;

-- Lead and lag for comparisons
SELECT 
  month,
  revenue,
  LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
  LEAD(revenue) OVER (ORDER BY month) AS next_month_revenue,
  revenue - LAG(revenue) OVER (ORDER BY month) AS month_over_month_change
FROM `project.dataset.monthly_revenue`;
```

----------------------------------------

TITLE: BigQuery Cost Optimization
DESCRIPTION: Strategies for optimizing costs when using BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/best-practices-costs

LANGUAGE: APIDOC
CODE:
```
Cost Optimization Strategies:

1. Query Optimization:
   - Use SELECT only needed columns (avoid SELECT *)
   - Use partition and cluster pruning
   - Use APPROX functions when exact results aren't needed
   - Preview queries with --dry_run flag

2. Storage Optimization:
   - Set table expiration for temporary data
   - Use partitioning to archive old data
   - Consider using BigQuery Storage API for large exports

3. Slot Optimization:
   - Use on-demand pricing for irregular workloads
   - Use flat-rate pricing for predictable workloads
   - Monitor slot usage in Cloud Console

4. Data Lifecycle:
   bq update --default_table_expiration 7776000 mydataset
   bq update --default_partition_expiration 2592000 mydataset
```

----------------------------------------

TITLE: BigQuery ML Quickstart
DESCRIPTION: Getting started with machine learning in BigQuery using BQML.

SOURCE: https://cloud.google.com/bigquery-ml/docs/quickstarts

LANGUAGE: SQL
CODE:
```sql
-- Create a linear regression model
CREATE OR REPLACE MODEL `project.dataset.price_model`
OPTIONS(
  model_type='linear_reg',
  input_label_cols=['price']
) AS
SELECT 
  price,
  size,
  location,
  bedrooms,
  bathrooms
FROM `project.dataset.real_estate_data`
WHERE date < '2023-01-01';

-- Evaluate the model
SELECT *
FROM ML.EVALUATE(MODEL `project.dataset.price_model`,
  (SELECT * FROM `project.dataset.real_estate_data`
   WHERE date >= '2023-01-01'));

-- Make predictions
SELECT *
FROM ML.PREDICT(MODEL `project.dataset.price_model`,
  (SELECT * FROM `project.dataset.new_properties`));
```

----------------------------------------

TITLE: BigQuery Data Governance
DESCRIPTION: Implementing data governance features in BigQuery including column-level security and data masking.

SOURCE: https://cloud.google.com/bigquery/docs/column-level-security

LANGUAGE: SQL
CODE:
```sql
-- Create a table with column-level security
CREATE OR REPLACE TABLE `project.dataset.users` (
  user_id STRING,
  email STRING OPTIONS(description="PII - restricted access"),
  name STRING,
  ssn STRING OPTIONS(description="PII - highly restricted")
);

-- Grant column-level access
GRANT SELECT(user_id, name) ON TABLE `project.dataset.users` 
TO "user:analyst@example.com";

GRANT SELECT ON TABLE `project.dataset.users` 
TO "group:data-scientists@example.com";

-- Create a view with data masking
CREATE OR REPLACE VIEW `project.dataset.users_masked` AS
SELECT 
  user_id,
  CASE 
    WHEN SESSION_USER() IN ('trusted-user@example.com') THEN email
    ELSE CONCAT(SUBSTR(email, 1, 3), '****', SUBSTR(email, -4))
  END AS email,
  name
FROM `project.dataset.users`;
```

----------------------------------------

TITLE: BigQuery Information Schema
DESCRIPTION: Using INFORMATION_SCHEMA views to query metadata about datasets, tables, and jobs.

SOURCE: https://cloud.google.com/bigquery/docs/information-schema-intro

LANGUAGE: SQL
CODE:
```sql
-- Query table metadata
SELECT 
  table_catalog,
  table_schema,
  table_name,
  table_type,
  creation_time,
  ddl
FROM `project.region-us.INFORMATION_SCHEMA.TABLES`
WHERE table_schema = 'mydataset';

-- Query column metadata
SELECT 
  table_name,
  column_name,
  ordinal_position,
  data_type,
  is_nullable
FROM `project.region-us.INFORMATION_SCHEMA.COLUMNS`
WHERE table_schema = 'mydataset'
  AND table_name = 'mytable';

-- Query job history
SELECT 
  job_id,
  user_email,
  creation_time,
  statement_type,
  total_bytes_processed,
  total_slot_ms
FROM `project.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND statement_type = 'SELECT'
ORDER BY total_bytes_processed DESC
LIMIT 10;
```

----------------------------------------

TITLE: BigQuery Geospatial Functions
DESCRIPTION: Working with geographic data using BigQuery's geography functions.

SOURCE: https://cloud.google.com/bigquery/docs/gis-intro

LANGUAGE: SQL
CODE:
```sql
-- Create geography points and calculate distances
WITH locations AS (
  SELECT 
    store_id,
    ST_GEOGPOINT(longitude, latitude) AS location
  FROM `project.dataset.stores`
)
SELECT 
  a.store_id AS store_a,
  b.store_id AS store_b,
  ST_DISTANCE(a.location, b.location) AS distance_meters
FROM locations a
CROSS JOIN locations b
WHERE a.store_id < b.store_id;

-- Find points within a radius
SELECT 
  store_id,
  ST_GEOGPOINT(longitude, latitude) AS location
FROM `project.dataset.stores`
WHERE ST_DWITHIN(
  ST_GEOGPOINT(longitude, latitude),
  ST_GEOGPOINT(-122.084, 37.422),  -- Center point
  1000  -- Radius in meters
);

-- Work with polygons
SELECT 
  region_name,
  ST_AREA(region_polygon) / 1000000 AS area_km2,
  ST_PERIMETER(region_polygon) / 1000 AS perimeter_km
FROM `project.dataset.regions`;
```

----------------------------------------

TITLE: BigQuery External Tables
DESCRIPTION: Creating and querying external tables that reference data stored outside BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/external-tables

LANGUAGE: SQL
CODE:
```sql
-- Create external table referencing Cloud Storage
CREATE OR REPLACE EXTERNAL TABLE `project.dataset.events_external`
OPTIONS (
  format = 'PARQUET',
  uris = ['gs://mybucket/events/*.parquet']
);

-- Create external table with schema detection
CREATE OR REPLACE EXTERNAL TABLE `project.dataset.logs_external`
OPTIONS (
  format = 'CSV',
  uris = ['gs://mybucket/logs/*.csv'],
  autodetect = true,
  skip_leading_rows = 1
);

-- Query external table with partition pruning
SELECT *
FROM `project.dataset.events_external`
WHERE _FILE_NAME LIKE '%2023-01-01%';

-- Create materialized view over external table for performance
CREATE MATERIALIZED VIEW `project.dataset.events_cached`
AS SELECT * FROM `project.dataset.events_external`
WHERE date >= CURRENT_DATE() - 30;
```

----------------------------------------

TITLE: BigQuery Time Travel and Snapshots
DESCRIPTION: Using time travel to query historical data and create table snapshots.

SOURCE: https://cloud.google.com/bigquery/docs/time-travel

LANGUAGE: SQL
CODE:
```sql
-- Query table as it was 1 hour ago
SELECT *
FROM `project.dataset.mytable`
FOR SYSTEM_TIME AS OF TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

-- Recover deleted table (within 7 days)
CREATE TABLE `project.dataset.recovered_table`
AS SELECT * FROM `project.dataset.deleted_table`
FOR SYSTEM_TIME AS OF TIMESTAMP '2023-01-01 12:00:00';

-- Create a table snapshot
CREATE SNAPSHOT TABLE `project.dataset.mytable_snapshot_20230101`
CLONE `project.dataset.mytable`;

-- Query snapshot
SELECT * FROM `project.dataset.mytable_snapshot_20230101`;

-- Restore from snapshot
CREATE OR REPLACE TABLE `project.dataset.mytable`
CLONE `project.dataset.mytable_snapshot_20230101`;
```

----------------------------------------

TITLE: BigQuery Data Lineage and Audit Logs
DESCRIPTION: Tracking data lineage and accessing audit logs for compliance and debugging.

SOURCE: https://cloud.google.com/bigquery/docs/audit-logs

LANGUAGE: SQL
CODE:
```sql
-- Query audit logs for table access
SELECT
  protopayload_auditlog.authenticationInfo.principalEmail AS user_email,
  protopayload_auditlog.resourceName AS resource,
  protopayload_auditlog.methodName AS method,
  timestamp
FROM `project.dataset.cloudaudit_googleapis_com_data_access`
WHERE protopayload_auditlog.serviceName = 'bigquery.googleapis.com'
  AND protopayload_auditlog.resourceName LIKE '%mytable%'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);

-- Track column-level access
SELECT
  protopayload_auditlog.authenticationInfo.principalEmail,
  JSON_EXTRACT_SCALAR(protopayload_auditlog.metadataJson, '$.tableDataRead.fields') AS accessed_columns,
  timestamp
FROM `project.dataset.cloudaudit_googleapis_com_data_access`
WHERE protopayload_auditlog.methodName = 'google.cloud.bigquery.v2.TableService.ReadRows'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);
```

----------------------------------------

TITLE: BigQuery UDFs (User-Defined Functions)
DESCRIPTION: Creating and using user-defined functions in BigQuery for reusable logic.

SOURCE: https://cloud.google.com/bigquery/docs/user-defined-functions

LANGUAGE: SQL
CODE:
```sql
-- Create a SQL UDF
CREATE OR REPLACE FUNCTION `project.dataset.normalize_email`(email STRING)
RETURNS STRING
AS (
  LOWER(TRIM(email))
);

-- Create a JavaScript UDF
CREATE OR REPLACE FUNCTION `project.dataset.parse_user_agent`(user_agent STRING)
RETURNS STRUCT<browser STRING, version STRING, os STRING>
LANGUAGE js AS """
  var parser = new UAParser(user_agent);
  var result = parser.getResult();
  return {
    browser: result.browser.name || 'unknown',
    version: result.browser.version || 'unknown',
    os: result.os.name || 'unknown'
  };
""";

-- Use UDFs in queries
SELECT 
  user_id,
  `project.dataset.normalize_email`(email) AS normalized_email,
  `project.dataset.parse_user_agent`(user_agent) AS browser_info
FROM `project.dataset.users`;

-- Create a table function (TVF)
CREATE OR REPLACE TABLE FUNCTION `project.dataset.get_active_users`(
  start_date DATE,
  end_date DATE
)
AS (
  SELECT user_id, COUNT(*) AS activity_count
  FROM `project.dataset.events`
  WHERE DATE(timestamp) BETWEEN start_date AND end_date
  GROUP BY user_id
  HAVING activity_count > 5
);

-- Use table function
SELECT * FROM `project.dataset.get_active_users`('2023-01-01', '2023-01-31');
```

----------------------------------------

TITLE: BigQuery Materialized Views
DESCRIPTION: Creating and managing materialized views for query performance optimization.

SOURCE: https://cloud.google.com/bigquery/docs/materialized-views-intro

LANGUAGE: SQL
CODE:
```sql
-- Create a materialized view
CREATE MATERIALIZED VIEW `project.dataset.daily_sales_summary`
PARTITION BY DATE(date)
CLUSTER BY product_id
AS
SELECT 
  DATE(timestamp) AS date,
  product_id,
  SUM(amount) AS total_sales,
  COUNT(*) AS transaction_count,
  AVG(amount) AS avg_sale
FROM `project.dataset.sales`
GROUP BY date, product_id;

-- Query the materialized view (automatically uses cached data)
SELECT * 
FROM `project.dataset.daily_sales_summary`
WHERE date = '2023-01-01';

-- Force refresh of materialized view
REFRESH MATERIALIZED VIEW `project.dataset.daily_sales_summary`;

-- Check materialized view freshness
SELECT 
  table_name,
  last_refresh_time,
  refresh_interval_minutes
FROM `project.region-us.INFORMATION_SCHEMA.MATERIALIZED_VIEWS`
WHERE table_schema = 'dataset';
```

----------------------------------------

TITLE: BigQuery Streaming Inserts
DESCRIPTION: Using streaming inserts to load data into BigQuery in real-time.

SOURCE: https://cloud.google.com/bigquery/docs/streaming-data-into-bigquery

LANGUAGE: PYTHON
CODE:
```python
from google.cloud import bigquery
import json

# Initialize client
client = bigquery.Client()
table_id = "project.dataset.events"

# Prepare rows to insert
rows_to_insert = [
    {
        "event_id": "evt_123",
        "user_id": "user_456",
        "event_type": "page_view",
        "timestamp": "2023-01-01T12:00:00",
        "properties": json.dumps({"page": "/home", "referrer": "google"})
    },
    {
        "event_id": "evt_124",
        "user_id": "user_789",
        "event_type": "button_click",
        "timestamp": "2023-01-01T12:00:01",
        "properties": json.dumps({"button_id": "submit", "form": "signup"})
    }
]

# Stream rows to BigQuery
errors = client.insert_rows_json(table_id, rows_to_insert)

if errors:
    print(f"Errors occurred: {errors}")
else:
    print(f"Successfully streamed {len(rows_to_insert)} rows")

# Using template suffix for partitioning
table_id_with_suffix = f"{table_id}${datetime.now().strftime('%Y%m%d')}"
errors = client.insert_rows_json(table_id_with_suffix, rows_to_insert)
```

----------------------------------------

TITLE: BigQuery Search Index
DESCRIPTION: Creating and using search indexes for full-text search capabilities.

SOURCE: https://cloud.google.com/bigquery/docs/search-intro

LANGUAGE: SQL
CODE:
```sql
-- Create a search index on a table
CREATE SEARCH INDEX my_search_index 
ON `project.dataset.documents`(content, title, tags);

-- Use SEARCH function with the index
SELECT 
  document_id,
  title,
  SEARCH(content, 'machine learning') AS relevance_score
FROM `project.dataset.documents`
WHERE SEARCH(content, 'machine learning')
ORDER BY relevance_score DESC;

-- Complex search with multiple fields
SELECT *
FROM `project.dataset.documents`
WHERE SEARCH((title, content, tags), 'bigquery OR "data warehouse"')
  AND publication_date > '2023-01-01';

-- Update search index
REFRESH SEARCH INDEX my_search_index ON `project.dataset.documents`;

-- Drop search index
DROP SEARCH INDEX my_search_index ON `project.dataset.documents`;
```

----------------------------------------

TITLE: BigQuery Remote Functions
DESCRIPTION: Creating remote functions that call external APIs or Cloud Functions.

SOURCE: https://cloud.google.com/bigquery/docs/remote-functions

LANGUAGE: SQL
CODE:
```sql
-- Create a connection to Cloud Functions
CREATE OR REPLACE CONNECTION `project.us.my_connection`
OPTIONS (
  type = 'CLOUD_FUNCTION',
  endpoint = 'https://us-central1-project.cloudfunctions.net/my_function'
);

-- Create a remote function
CREATE OR REPLACE FUNCTION `project.dataset.sentiment_analysis`(text STRING)
RETURNS FLOAT64
REMOTE WITH CONNECTION `project.us.my_connection`
OPTIONS (
  endpoint = 'https://us-central1-project.cloudfunctions.net/analyze_sentiment'
);

-- Use remote function in queries
SELECT 
  comment_id,
  comment_text,
  `project.dataset.sentiment_analysis`(comment_text) AS sentiment_score
FROM `project.dataset.comments`
WHERE DATE(timestamp) = CURRENT_DATE();

-- Batch processing with remote functions
SELECT 
  product_id,
  ARRAY_AGG(review_text) AS reviews,
  AVG(`project.dataset.sentiment_analysis`(review_text)) AS avg_sentiment
FROM `project.dataset.product_reviews`
GROUP BY product_id;
```

----------------------------------------

TITLE: BigQuery BI Engine
DESCRIPTION: Using BI Engine for accelerated query performance in dashboards and reports.

SOURCE: https://cloud.google.com/bigquery/docs/bi-engine-intro

LANGUAGE: SQL
CODE:
```sql
-- Create BI Engine reservation
CREATE RESERVATION `project.region-us.bi_reservation`
OPTIONS (
  size_gb = 100,
  location = 'us'
);

-- Create aggregated table optimized for BI Engine
CREATE OR REPLACE TABLE `project.dataset.sales_summary_bi`
CLUSTER BY date, product_category
AS
SELECT 
  DATE(timestamp) AS date,
  product_category,
  region,
  SUM(revenue) AS total_revenue,
  COUNT(DISTINCT customer_id) AS unique_customers,
  COUNT(*) AS transaction_count
FROM `project.dataset.sales`
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY date, product_category, region;

-- Add table to BI Engine reservation
ALTER TABLE `project.dataset.sales_summary_bi`
SET OPTIONS (
  bi_engine_mode = 'FULL'
);

-- Query will be accelerated by BI Engine
SELECT 
  product_category,
  SUM(total_revenue) AS revenue
FROM `project.dataset.sales_summary_bi`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY product_category
ORDER BY revenue DESC;
```

----------------------------------------

TITLE: BigQuery Change Data Capture (CDC)
DESCRIPTION: Implementing change data capture patterns in BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/change-data-capture

LANGUAGE: SQL
CODE:
```sql
-- Create a table with CDC metadata
CREATE OR REPLACE TABLE `project.dataset.customers_cdc` (
  customer_id STRING,
  name STRING,
  email STRING,
  operation STRING,  -- INSERT, UPDATE, DELETE
  change_timestamp TIMESTAMP,
  is_current BOOLEAN
)
PARTITION BY DATE(change_timestamp)
CLUSTER BY customer_id, is_current;

-- Process CDC events
MERGE `project.dataset.customers_cdc` AS target
USING (
  SELECT 
    customer_id,
    name,
    email,
    operation,
    CURRENT_TIMESTAMP() AS change_timestamp,
    TRUE AS is_current
  FROM `project.dataset.customers_staging`
) AS source
ON target.customer_id = source.customer_id AND target.is_current = TRUE
WHEN MATCHED AND source.operation != 'DELETE' THEN
  UPDATE SET 
    target.is_current = FALSE
WHEN MATCHED AND source.operation = 'DELETE' THEN
  UPDATE SET 
    target.is_current = FALSE,
    target.operation = 'DELETE'
WHEN NOT MATCHED THEN
  INSERT (customer_id, name, email, operation, change_timestamp, is_current)
  VALUES (source.customer_id, source.name, source.email, source.operation, source.change_timestamp, TRUE);

-- Query current state
SELECT * EXCEPT(operation, change_timestamp, is_current)
FROM `project.dataset.customers_cdc`
WHERE is_current = TRUE AND operation != 'DELETE';

-- Query historical state at a point in time
SELECT * EXCEPT(operation, change_timestamp, is_current)
FROM `project.dataset.customers_cdc`
WHERE change_timestamp <= '2023-01-01 00:00:00'
  AND customer_id NOT IN (
    SELECT customer_id 
    FROM `project.dataset.customers_cdc`
    WHERE change_timestamp <= '2023-01-01 00:00:00'
      AND operation = 'DELETE'
  )
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY change_timestamp DESC) = 1;
```

----------------------------------------

TITLE: BigQuery JSON Functions
DESCRIPTION: Working with JSON data in BigQuery using JSON functions.

SOURCE: https://cloud.google.com/bigquery/docs/json-data

LANGUAGE: SQL
CODE:
```sql
-- Extract values from JSON strings
SELECT 
  JSON_EXTRACT_SCALAR(json_data, '$.user.name') AS user_name,
  JSON_EXTRACT_SCALAR(json_data, '$.user.email') AS user_email,
  CAST(JSON_EXTRACT_SCALAR(json_data, '$.user.age') AS INT64) AS user_age,
  JSON_EXTRACT_ARRAY(json_data, '$.items') AS items_array
FROM `project.dataset.json_table`;

-- Query nested JSON arrays
SELECT 
  user_id,
  JSON_EXTRACT_SCALAR(item, '$.product_id') AS product_id,
  CAST(JSON_EXTRACT_SCALAR(item, '$.quantity') AS INT64) AS quantity
FROM `project.dataset.orders`,
UNNEST(JSON_EXTRACT_ARRAY(order_data, '$.items')) AS item;

-- Build JSON objects
SELECT 
  TO_JSON_STRING(
    STRUCT(
      user_id,
      name,
      ARRAY_AGG(
        STRUCT(order_id, order_date, total)
      ) AS orders
    )
  ) AS user_json
FROM `project.dataset.users` u
LEFT JOIN `project.dataset.orders` o USING(user_id)
GROUP BY user_id, name;

-- Parse and validate JSON
SELECT 
  SAFE.JSON_EXTRACT_SCALAR(json_data, '$.field') AS safe_extract,
  CASE 
    WHEN SAFE.JSON_EXTRACT_SCALAR(json_data, '$') IS NULL THEN 'Invalid JSON'
    ELSE 'Valid JSON'
  END AS json_validity
FROM `project.dataset.raw_data`;
```

----------------------------------------

TITLE: BigQuery Row-Level Security
DESCRIPTION: Implementing row-level security using policy tags and row access policies.

SOURCE: https://cloud.google.com/bigquery/docs/row-level-security

LANGUAGE: SQL
CODE:
```sql
-- Create row access policy based on user
CREATE ROW ACCESS POLICY sales_team_policy
ON `project.dataset.sales`
GRANT TO ('user:sales@example.com', 'group:sales-team@example.com')
FILTER USING (region = 'US');

CREATE ROW ACCESS POLICY manager_policy
ON `project.dataset.sales`
GRANT TO ('user:manager@example.com')
FILTER USING (TRUE);  -- Managers see all rows

-- Create row access policy with session user
CREATE ROW ACCESS POLICY user_data_policy
ON `project.dataset.user_data`
GRANT TO ('group:all-users@example.com')
FILTER USING (user_email = SESSION_USER());

-- List row access policies
SELECT *
FROM `project.dataset.INFORMATION_SCHEMA.ROW_ACCESS_POLICIES`
WHERE table_name = 'sales';

-- Drop row access policy
DROP ROW ACCESS POLICY sales_team_policy ON `project.dataset.sales`;

-- Create view with additional filtering
CREATE OR REPLACE VIEW `project.dataset.sales_filtered` AS
SELECT *
FROM `project.dataset.sales`
WHERE amount > 100  -- Additional business logic filter
-- Row access policies from base table are automatically applied
```

----------------------------------------

TITLE: BigQuery Export and Import
DESCRIPTION: Exporting data from BigQuery and importing from various sources.

SOURCE: https://cloud.google.com/bigquery/docs/exporting-data

LANGUAGE: SQL
CODE:
```sql
-- Export to Cloud Storage
EXPORT DATA OPTIONS(
  uri='gs://mybucket/exports/sales_*.csv',
  format='CSV',
  overwrite=true,
  header=true
) AS
SELECT * FROM `project.dataset.sales`
WHERE date >= '2023-01-01';

-- Export as Parquet with compression
EXPORT DATA OPTIONS(
  uri='gs://mybucket/exports/sales_*.parquet',
  format='PARQUET',
  overwrite=false,
  compression='SNAPPY'
) AS
SELECT * FROM `project.dataset.sales`
WHERE date >= '2023-01-01';

-- Export as JSON
EXPORT DATA OPTIONS(
  uri='gs://mybucket/exports/sales_*.json',
  format='JSON',
  overwrite=true
) AS
SELECT * FROM `project.dataset.sales`;

-- Load data from Cloud Storage
LOAD DATA INTO `project.dataset.sales`
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://mybucket/imports/sales_*.parquet']
);

-- Load with schema auto-detection
LOAD DATA INTO `project.dataset.new_table`
FROM FILES (
  format = 'CSV',
  uris = ['gs://mybucket/imports/data.csv'],
  skip_leading_rows = 1,
  autodetect = true
);
```

----------------------------------------

TITLE: BigQuery Scheduled Queries
DESCRIPTION: Creating and managing scheduled queries for automated data processing.

SOURCE: https://cloud.google.com/bigquery/docs/scheduling-queries

LANGUAGE: SQL
CODE:
```sql
-- Create scheduled query using bq command
-- bq query \
--   --use_legacy_sql=false \
--   --destination_table=project:dataset.daily_summary \
--   --display_name='Daily Sales Summary' \
--   --schedule='every day 02:00' \
--   --replace \
--   'SELECT DATE(timestamp) as date, 
--           SUM(amount) as total_sales 
--    FROM `project.dataset.sales` 
--    WHERE DATE(timestamp) = CURRENT_DATE() - 1
--    GROUP BY date'

-- Using scheduled query with parameters
DECLARE run_date DATE DEFAULT CURRENT_DATE() - 1;

CREATE OR REPLACE TABLE `project.dataset.daily_summary`
PARTITION BY date
AS
SELECT 
  DATE(timestamp) AS date,
  product_id,
  SUM(amount) AS total_sales,
  COUNT(*) AS transaction_count
FROM `project.dataset.sales`
WHERE DATE(timestamp) = run_date
GROUP BY date, product_id;

-- Monitor scheduled queries
SELECT 
  job_id,
  creation_time,
  statement_type,
  destination_table,
  total_bytes_processed,
  error_result
FROM `project.region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE job_id LIKE 'scheduled_query_%'
  AND creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY creation_time DESC;
```

----------------------------------------

TITLE: BigQuery Data Validation
DESCRIPTION: Implementing data quality checks and validation rules in BigQuery.

SOURCE: https://cloud.google.com/bigquery/docs/data-validation

LANGUAGE: SQL
CODE:
```sql
-- Create data validation rules table
CREATE OR REPLACE TABLE `project.dataset.data_quality_rules` (
  rule_id STRING,
  table_name STRING,
  rule_type STRING,
  rule_sql STRING,
  severity STRING,
  description STRING
);

-- Insert validation rules
INSERT INTO `project.dataset.data_quality_rules` VALUES
('rule_001', 'sales', 'completeness', 
 'SELECT COUNT(*) FROM `project.dataset.sales` WHERE amount IS NULL',
 'ERROR', 'Check for null amounts'),
('rule_002', 'sales', 'validity',
 'SELECT COUNT(*) FROM `project.dataset.sales` WHERE amount < 0',
 'WARNING', 'Check for negative amounts'),
('rule_003', 'customers', 'uniqueness',
 'SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM `project.dataset.customers`',
 'ERROR', 'Check for duplicate customer IDs');

-- Execute validation rules
CREATE OR REPLACE PROCEDURE `project.dataset.run_data_validation`()
BEGIN
  DECLARE rule STRUCT<rule_id STRING, table_name STRING, rule_sql STRING, severity STRING>;
  DECLARE validation_result INT64;
  
  FOR rule IN (SELECT rule_id, table_name, rule_sql, severity FROM `project.dataset.data_quality_rules`)
  DO
    EXECUTE IMMEDIATE rule.rule_sql INTO validation_result;
    
    INSERT INTO `project.dataset.validation_results` 
    VALUES (rule.rule_id, rule.table_name, validation_result, 
            CASE WHEN validation_result > 0 THEN 'FAILED' ELSE 'PASSED' END,
            rule.severity, CURRENT_TIMESTAMP());
  END FOR;
END;

-- Call validation procedure
CALL `project.dataset.run_data_validation`();

-- Check validation results
SELECT *
FROM `project.dataset.validation_results`
WHERE status = 'FAILED'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY severity, timestamp DESC;
```

