-- This script creates tables for storing Ethereum Name Service (ENS) data in BigQuery.
-- See table_documentation.md for detailed column descriptions.

CREATE OR REPLACE TABLE ens_temp.labels (
    labelHash BYTES,
    label STRING
);

CREATE OR REPLACE TABLE ens_temp.registry (
    node BYTES,
    labelHash BYTES,
    parentNode BYTES,
    owner STRING,
    resolver STRING,
    name STRING
);

CREATE OR REPLACE TABLE ens_temp.resolvers (
    address BYTES,
    node BYTES,
    addr STRING,
    texts STRING,
    addresses STRING,
    contenthash BYTES,
    reverseName STRING
);

CREATE OR REPLACE TABLE ens_temp.resolutions (
    node BYTES,
    name STRING,
    addr STRING,
    texts STRING,
    addresses STRING
);

CREATE OR REPLACE TABLE ens_temp.reverse_records (
    name STRING,
    address STRING
);

CREATE OR REPLACE TABLE ens_temp.registration_periods (
    labelhash STRING,
    event_timestamp TIMESTAMP,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    cost FLOAT64,
    premium FLOAT64,
    event STRING
);