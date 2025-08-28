-- ========================================
-- ENS BigQuery Functions
-- ========================================
-- This file contains all user-defined functions used in the ENS BigQuery pipeline
-- Functions are created as permanent functions in the dataset

-- ========================================
-- 1. ENS Node Computation Function
-- ========================================
-- Computes ENS node hash from parent node and label hash
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.COMPUTE_ENS_NODE`(parent_node STRING, label_hash STRING)
RETURNS STRING
LANGUAGE js
OPTIONS (
  library=["gs://blockchain-etl-bigquery/ethers.js"])
AS r"""
  var utils = ethers.utils;
  if(parent_node === null || label_hash === null) return null;
  try{
    var parent = parent_node.startsWith('0x') ? parent_node.slice(2) : parent_node;
    var label = label_hash.startsWith('0x') ? label_hash.slice(2) : label_hash;
    var combined = '0x' + parent + label;
    return utils.keccak256(combined);
  }catch(e){
    return null;
  }
""";

-- ========================================
-- 2. ENS Namehash Function
-- ========================================
-- Computes namehash for ENS names (used for reverse records)
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.NAMEHASH`(data STRING)
RETURNS STRING
LANGUAGE js
OPTIONS (
  library="gs://blockchain-etl-bigquery/ethers.js" )
AS """
  try {
    return ethers.utils.namehash(data);
  } catch(e) {
      return null;
  }
""";

-- ========================================
-- 3. ABI String Decoder Function
-- ========================================
-- Decodes ABI-encoded string parameters from event data
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.DECODE_ABI_STRING`(data STRING, param_index INT64)
RETURNS STRING
LANGUAGE js AS """
  try {
    if (!data || data.length < 2) return null;
    
    // Remove 0x prefix
    const hex = data.substr(2);
    
    // Get the offset for the parameter (64 chars per offset)
    const offsetStart = (param_index - 1) * 64;
    const offsetHex = hex.substr(offsetStart, 64);
    const offset = parseInt(offsetHex, 16);
    
    // Convert byte offset to hex position (2 hex chars per byte)
    const dataStart = offset * 2;
    
    // Get length (next 64 hex chars after offset)
    const lengthHex = hex.substr(dataStart, 64);
    const length = parseInt(lengthHex, 16);
    
    if (length === 0) return '';
    
    // Get the actual string data
    const stringStart = dataStart + 64;
    const stringHex = hex.substr(stringStart, length * 2);
    
    // Convert hex to UTF-8 string
    let result = '';
    for (let i = 0; i < stringHex.length; i += 2) {
      const byte = parseInt(stringHex.substr(i, 2), 16);
      if (byte !== 0) {  // Skip null bytes
        result += String.fromCharCode(byte);
      }
    }
    
    return result;
  } catch(e) {
    return null;
  }
""";

-- ========================================
-- 4. ABI Boolean Decoder Function
-- ========================================
-- Decodes ABI-encoded boolean values from event data
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.DECODE_ABI_BOOL`(data STRING)
RETURNS BOOL
LANGUAGE js AS """
  try {
    if (!data || data.length < 66) return null;
    const hex = data.substr(2);
    const boolHex = hex.substr(hex.length - 2, 2);
    return parseInt(boolHex, 16) === 1;
  } catch(e) {
    return null;
  }
""";

-- ========================================
-- 5. Extract Name from Controller Events
-- ========================================
-- Extracts ENS name from ABI-encoded NameRegistered/NameRenewed event data
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.EXTRACT_NAME_FROM_ABI_DATA`(data STRING)
RETURNS STRING
LANGUAGE js AS """
  try {
    if (!data || data.length < 200) return null;
    
    // Remove 0x prefix if present
    const cleanData = data.startsWith('0x') ? data.slice(2) : data;
    
    // Read the string pointer from first 32 bytes
    const stringPointer = parseInt(cleanData.substr(0, 64), 16);
    
    // Valid pointers for different controller versions:
    // Controller v1-v3: 0x60 (96 bytes) - name after cost and expires  
    // Controller v4: 0x80 (128 bytes) - name after baseCost, premium, and expires
    if (stringPointer !== 96 && stringPointer !== 128) {
      return null;
    }
    
    // Calculate where the string length starts (pointer * 2 for hex chars)
    const lengthPosition = stringPointer * 2;
    const lengthHex = cleanData.substr(lengthPosition, 64);
    const nameLength = parseInt(lengthHex, 16);
    
    if (nameLength > 100 || nameLength === 0) return null;
    
    // Extract name data (starts 32 bytes after length)
    const namePosition = lengthPosition + 64;
    const nameHex = cleanData.substr(namePosition, nameLength * 2);
    
    if (nameHex.length < nameLength * 2) return null;
    
    // Convert hex to ASCII string
    let name = '';
    for (let i = 0; i < nameHex.length; i += 2) {
      const charCode = parseInt(nameHex.substr(i, 2), 16);
      if (charCode >= 32 && charCode <= 126) { // Printable ASCII
        name += String.fromCharCode(charCode);
      }
    }
    
    return name || null;
  } catch(e) {
    return null;
  }
""";

-- ========================================
-- 6. Content Hash Decoder (Custom)
-- ========================================
-- Decodes ENS content hashes to human-readable format
-- Supports IPFS, IPNS, Swarm, Arweave, Skynet, Onion
CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.decodeContentHashCustom`(contentHash STRING)
RETURNS STRUCT<decoded STRING, content_type STRING>
LANGUAGE js AS r"""
  if (!contentHash || contentHash === '0x' || contentHash === '') {
    return {decoded: null, content_type: null};
  }
  
  try {
    // Remove 0x prefix if present
    let hex = contentHash.startsWith('0x') ? contentHash.slice(2) : contentHash;
    
    // Convert hex to bytes
    let bytes = [];
    for (let i = 0; i < hex.length; i += 2) {
      bytes.push(parseInt(hex.substr(i, 2), 16));
    }
    
    if (bytes.length === 0) {
      return {decoded: null, content_type: null};
    }
    
    // Decode varint to get codec
    let codecValue = 0;
    let codecLength = 0;
    for (let i = 0; i < bytes.length && i < 9; i++) {
      const byte = bytes[i];
      codecValue |= (byte & 0x7F) << (7 * i);
      codecLength++;
      if ((byte & 0x80) === 0) break;
    }
    
    // Get content bytes after codec
    const contentBytes = bytes.slice(codecLength);
    
    // Helper functions
    const bytesToBase58 = (bytes) => {
      const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
      let result = '';
      let num = BigInt(0);
      for (let i = 0; i < bytes.length; i++) {
        num = num * BigInt(256) + BigInt(bytes[i]);
      }
      while (num > 0) {
        result = ALPHABET[Number(num % BigInt(58))] + result;
        num = num / BigInt(58);
      }
      return result;
    };
    
    const bytesToBase32 = (bytes) => {
      const ALPHABET = 'abcdefghijklmnopqrstuvwxyz234567';
      let bits = '';
      for (let byte of bytes) {
        bits += byte.toString(2).padStart(8, '0');
      }
      let result = '';
      for (let i = 0; i < bits.length; i += 5) {
        const chunk = bits.substr(i, 5).padEnd(5, '0');
        result += ALPHABET[parseInt(chunk, 2)];
      }
      return result;
    };
    
    const bytesToBase64Url = (bytes) => {
      let binary = '';
      for (let byte of bytes) {
        binary += String.fromCharCode(byte);
      }
      // Standard base64
      let base64 = btoa(binary);
      // Convert to base64url
      return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
    };
    
    const bytesToHex = (bytes) => {
      return bytes.map(b => b.toString(16).padStart(2, '0')).join('');
    };
    
    const bytesToUtf8 = (bytes) => {
      let result = '';
      for (let byte of bytes) {
        if (byte >= 32 && byte < 127) {
          result += String.fromCharCode(byte);
        }
      }
      return result;
    };
    
    // Decode based on codec
    switch(codecValue) {
      case 0xe3: // IPFS (CIDv0)
        return {
          decoded: '1220' + bytesToHex(contentBytes),
          content_type: 'ipfs'
        };
        
      case 0x0172: // IPNS 
        return {
          decoded: 'k51q' + bytesToBase58(contentBytes),
          content_type: 'ipns'
        };
        
      case 0xe4: // Swarm
        return {
          decoded: bytesToHex(contentBytes),
          content_type: 'swarm'
        };
        
      case 0xe5: // Skynet
        return {
          decoded: bytesToBase64Url(contentBytes),
          content_type: 'skynet'
        };
        
      case 0x01bc: // Onion
        return {
          decoded: bytesToUtf8(contentBytes),
          content_type: 'onion'
        };
        
      case 0x01bd: // Onion3
        return {
          decoded: bytesToBase32(contentBytes).toLowerCase() + '.onion',
          content_type: 'onion3'
        };
        
      case 0x01b8: // Arweave
        return {
          decoded: bytesToBase64Url(contentBytes),
          content_type: 'arweave'
        };
        
      default:
        // Try to decode as IPFS CIDv1 if it looks like one
        if (codecValue === 0x01 && contentBytes.length > 2) {
          // This might be a CIDv1
          const hash_fn = contentBytes[0];
          const hash_len = contentBytes[1];
          if (hash_fn === 0x12 && hash_len === 0x20) { // SHA2-256
            return {
              decoded: 'ba' + bytesToBase32(bytes).toLowerCase(),
              content_type: 'ipfs'
            };
          }
        }
        return {
          decoded: '0x' + hex,
          content_type: 'unknown_' + codecValue.toString(16)
        };
    }
  } catch(e) {
    return {decoded: null, content_type: 'error: ' + e.toString()};
  }
""";

-- ========================================
-- 7. Content Hash Functions (using ENS library)
-- ========================================
-- These functions use the official ENS content-hash library
-- Note: May have compatibility issues with BigQuery JavaScript runtime

CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.decodeContentHash`(contentHash STRING)
RETURNS STRING
LANGUAGE js
OPTIONS (
  library=["gs://jsassets/content-hash-3-0-0-beta-5.js"])
AS r"""
  try {
    return contentHash ? contentHashLib.decode(contentHash) : null;
  } catch(e) {
    return null;
  }
""";

CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.encodeContentHash`(codec STRING, value STRING)
RETURNS STRING
LANGUAGE js
OPTIONS (
  library=["gs://jsassets/content-hash-3-0-0-beta-5.js"])
AS r"""
  return contentHashLib.encode(codec, value);
""";

CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.getContentHashCodec`(contentHash STRING)
RETURNS STRING
LANGUAGE js
OPTIONS (
  library=["gs://jsassets/content-hash-3-0-0-beta-5.js"])
AS r"""
  try {
    return contentHash ? contentHashLib.getCodec(contentHash) : null;
  } catch(e) {
    return null;
  }
""";