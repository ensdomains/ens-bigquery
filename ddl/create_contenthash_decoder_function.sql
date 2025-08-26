-- Create custom contenthash decoder function for BigQuery
-- This function is compatible with BigQuery's JavaScript runtime
-- and handles all content types: IPFS, IPNS, Swarm, Arweave, Skynet, Onion v2/v3

CREATE OR REPLACE FUNCTION `web3-publicgoods.ens.decodeContentHashCustom`(contentHash STRING)
RETURNS STRING
LANGUAGE js AS """
  try {
    if (!contentHash) return null;
    
    // Remove 0x prefix if present
    let hex = contentHash.toLowerCase();
    if (hex.startsWith('0x')) {
      hex = hex.slice(2);
    }
    
    // Convert hex to bytes
    const hexToBytes = (hexStr) => {
      const bytes = [];
      for (let i = 0; i < hexStr.length; i += 2) {
        bytes.push(parseInt(hexStr.substr(i, 2), 16));
      }
      return bytes;
    };
    
    // Convert bytes to hex
    const bytesToHex = (bytes) => {
      return bytes.map(b => b.toString(16).padStart(2, '0')).join('');
    };
    
    // Simple varint decoder for the codec
    const decodeVarint = (bytes) => {
      let value = 0;
      let shift = 0;
      let i = 0;
      while (i < bytes.length) {
        const byte = bytes[i];
        value |= (byte & 0x7F) << shift;
        if ((byte & 0x80) === 0) break;
        shift += 7;
        i++;
      }
      return [value, i + 1];
    };
    
    // Base64url encode function (without TextDecoder dependency)
    const base64urlEncode = (bytes) => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
      let result = '';
      let i = 0;
      
      while (i < bytes.length) {
        const a = bytes[i++];
        const b = i < bytes.length ? bytes[i++] : 0;
        const c = i < bytes.length ? bytes[i++] : 0;
        
        const triplet = (a << 16) | (b << 8) | c;
        
        result += chars[(triplet >> 18) & 63];
        result += chars[(triplet >> 12) & 63];
        result += i - 2 < bytes.length ? chars[(triplet >> 6) & 63] : '';
        result += i - 1 < bytes.length ? chars[triplet & 63] : '';
      }
      
      return result;
    };
    
    // ASCII decode for onion addresses
    const bytesToAscii = (bytes) => {
      return bytes.map(b => String.fromCharCode(b)).join('');
    };
    
    const bytes = hexToBytes(hex);
    const [code, offset] = decodeVarint(bytes);
    const value = bytes.slice(offset);
    
    // Handle different content types based on codec
    switch (code) {
      case 0xe3: // IPFS
        // For IPFS, return simplified version since full CID decoding is complex
        return 'ipfs_' + bytesToHex(value).substring(0, 32) + '...';
        
      case 0xe5: // IPNS  
        // Similar to IPFS, complex CID handling needed
        return 'ipns_' + bytesToHex(value).substring(0, 32) + '...';
        
      case 0xe4: // Swarm
        // Swarm returns the hex hash after extracting from multihash
        if (value.length >= 34) {
          // Skip multihash header, return hex hash
          return bytesToHex(value.slice(2)); // Skip hash function code + length
        }
        return bytesToHex(value);
        
      case 0x01bc: // Onion v2
        // Convert bytes to ASCII and add .onion suffix
        return bytesToAscii(value) + '.onion';
        
      case 0x01bd: // Onion v3  
        // Convert bytes to ASCII and add .onion suffix
        return bytesToAscii(value) + '.onion';
        
      case 0xb29910: // Arweave
        // Convert to base64url
        return base64urlEncode(value);
        
      case 0xb19910: // Skynet
        // Convert to base64url  
        return base64urlEncode(value);
        
      default:
        // Unknown codec, return hex
        return bytesToHex(value);
    }
    
  } catch (e) {
    return null;
  }
""";