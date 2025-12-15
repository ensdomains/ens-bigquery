MERGE `ens-manager.names.controller_traces` T
USING (
  -- 1. Deduplicate the source data before merging
  SELECT * FROM (
    SELECT
      block_timestamp, value, from_address, to_address, 
      transaction_hash, trace_address, input, output,
      -- Rank rows to identify duplicates in the source
      ROW_NUMBER() OVER(
        PARTITION BY transaction_hash, trace_address 
        ORDER BY block_timestamp
      ) as row_num
    FROM
      `bigquery-public-data.crypto_ethereum.traces`
    WHERE
      (from_address in ("0x59e16fccd424cc24e280be16e11bcd56fb0ce547", "0x253553366da8546fc250f225fe3d25d0c782303b")
        OR to_address in ("0x59e16fccd424cc24e280be16e11bcd56fb0ce547", "0x253553366da8546fc250f225fe3d25d0c782303b"))
      AND status = 1
      AND DATE(block_timestamp) = DATE_SUB(@run_date, INTERVAL 1 DAY)
  )
  WHERE row_num = 1 -- Only keep one copy of each trace
) S
ON T.transaction_hash = S.transaction_hash 
   -- 2. Handle NULLs safely using IFNULL or COALESCE
   AND IFNULL(T.trace_address, 'TOP_LEVEL') = IFNULL(S.trace_address, 'TOP_LEVEL')

WHEN NOT MATCHED THEN
  INSERT (
    block_timestamp, value, from_address, to_address, 
    transaction_hash, trace_address, input, output
  )
  VALUES (
    block_timestamp, value, from_address, to_address, 
    transaction_hash, trace_address, input, output
  )