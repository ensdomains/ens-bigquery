SELECT
  DATE(block_timestamp) AS day,
  from_address,
  COUNT(*) AS count
FROM
  `bigquery-public-data.crypto_ethereum.traces`
WHERE
  to_address IN ( '0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e',
    '0x084b1c3c81545d370f3634392de611caabff8148',
    '0x1da022710df5002339274aadee8d58218e9d6ab5',
    '0x231b0ee14048e9dccd1d247744d114a4eb5e8e63',
    '0x253553366da8546fc250f225fe3d25d0c782303b',
    '0x21745ff62108968fbf5ab1e07961cc0fcbeb2364',
    '0x226159d592e2b063810a10ebf6dcbada94ed68b8',
    '0x253553366da8546fc250f225fe3d25d0c782303b',
    '0x283af0b28c62c092c9727f1ee09c02ca627eb7f5',
    '0x314159265dd8dbb310642f98f50c066173c1259b',
    '0x4976fb03c32e5b8cfe2b6ccb31c09ba78ebaba41',
    '0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85',
    '0x58774bb8acd458a640af0b88238369a167546ef2',
    '0x6090a6e47849629b7245dfa1ca21d94cd15878ef',
    '0x9062c0a6dbd6108336bcbe4593a3d1ce05512069',
    '0xa2c122be93b0074270ebee7f6b7292c7deb45047',
    '0xa58e81fe9b61b5c3fe2afd33cf304c454abfc7cb',
    '0xb22c1c159d12461ea124b0deb4b5b93020e6ad16',
    '0xdaaf96c344f63131acadd0ea35170e7892d3dfba',
    '0xf0ad5cad05e10572efceb849f6ff0c68f9700455')
GROUP BY
  day,
  from_address
