-- This script creates tables for storing Ethereum Name Service (ENS) data in BigQuery.
-- See table_documentation.md for detailed column descriptions.

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.labels` (
    labelHash BYTES,
    label STRING
);

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.registry` (
    node BYTES,
    labelHash BYTES,
    parentNode BYTES,
    owner STRING,
    resolver STRING,
    name STRING
);

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.resolvers` (
    address STRING,
    node STRING,
    addr STRING,
    text_records ARRAY<STRUCT<key STRING, value STRING>>,
    texts STRING,
    addresses STRING,
    contenthash STRING,
    raw_contenthash STRING,
    decoded_contenthash STRING,
    content_type STRING,
    reverseName STRING
);

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.resolutions` (
    node BYTES,
    name STRING,
    addr STRING,
    texts STRING,
    addresses STRING
);

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.reverse_records` (
    name STRING,
    address STRING
);

CREATE OR REPLACE TABLE `web3-publicgoods.ens_temp2.registration_periods` (
    labelhash STRING,
    label STRING,
    event_timestamp TIMESTAMP,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    cost FLOAT64,
    event STRING,
    duration_years FLOAT64,
    base_cost_usd_per_year FLOAT64,
    base_cost_usd FLOAT64,
    premium FLOAT64,
    eth_usd_rate FLOAT64,
    premium_usd FLOAT64
);