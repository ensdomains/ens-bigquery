  CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.decodeContentHash`(contentHash STRING)
  RETURNS STRING
  LANGUAGE js
  OPTIONS (
    library = ["gs://jsassets/content-hash-3-0-0-beta-5.js"]
  )
  AS r"""
    return ContentHash.decode(contentHash);
  """;



  -- Create a function to encode content hashes
  CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.encodeContentHash`(codec STRING, value STRING)
  RETURNS STRING
  LANGUAGE js
  OPTIONS (
    library = ["gs://jsassets/content-hash-3-0-0-beta-5.js"]
  )
  AS r"""
    return ContentHash.encode(codec, value);
  """;

  -- Create a function to get the codec type
  CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.getContentHashCodec`(contentHash STRING)
  RETURNS STRING
  LANGUAGE js
  OPTIONS (
    library = ["gs://jsassets/content-hash-3-0-0-beta-5.js"]
  )
  AS r"""
    return ContentHash.getCodec(contentHash);
  """;