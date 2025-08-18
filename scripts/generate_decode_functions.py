#!/usr/bin/env python3
"""
Generate BigQuery UDF functions for decoding ENS events.
Usage: python generate_decode_functions.py
"""

import yaml
import hashlib

def keccak256_event_signature(signature):
    """Generate keccak256 hash for event signature (simplified - use actual keccak256 in production)"""
    # This is a placeholder - use actual keccak256 implementation
    return '0x' + hashlib.sha256(signature.encode()).hexdigest()[:64]

def generate_decode_function(event_type, contracts, project_id="web3-publicgoods", dataset_id="ens_temp"):
    """Generate a UDF function for decoding events of a specific type"""
    
    function_name = f"decode_{event_type}_events"
    
    # Collect all unique events across contracts of this type
    all_events = {}
    for contract in contracts:
        if contract.get('event_type') == event_type:
            for event in contract.get('events', []):
                event_name = event['name']
                if event_name not in all_events:
                    all_events[event_name] = event
    
    # Generate return struct
    return_fields = ["decoded BOOL", "event_name STRING"]
    
    # Add fields for each possible parameter
    all_params = set()
    for event in all_events.values():
        for param in event.get('parameters', []):
            all_params.add((param['name'], param['type']))
    
    for param_name, param_type in sorted(all_params):
        bq_type = convert_solidity_to_bq_type(param_type)
        return_fields.append(f"{param_name} {bq_type}")
    
    return_struct = ",\n  ".join(return_fields)
    
    # Generate event signature mappings
    event_mappings = []
    for event_name, event in all_events.items():
        signature = event['signature']
        # In production, use actual keccak256
        sig_hash = keccak256_event_signature(signature)
        event_mappings.append(f"    '{sig_hash}': '{event_name}'")
    
    event_mappings_str = ",\n".join(event_mappings)
    
    # Generate decoding cases
    decode_cases = []
    for event_name, event in all_events.items():
        case_lines = [f"      case '{event_name}':"]
        
        topic_index = 1
        data_offset = 0
        
        for param in event.get('parameters', []):
            param_name = param['name']
            param_type = param['type']
            is_indexed = param['indexed']
            
            if is_indexed:
                case_lines.append(f"        result.{param_name} = topics[{topic_index}] || null;")
                topic_index += 1
            else:
                if param_type in ['address']:
                    case_lines.append(f"        result.{param_name} = data ? '0x' + data.slice({26 + data_offset * 64}, {66 + data_offset * 64}) : null;")
                elif param_type in ['uint256', 'uint64']:
                    case_lines.append(f"        result.{param_name} = data ? parseInt(data.slice({2 + data_offset * 64}, {66 + data_offset * 64}), 16) : null;")
                else:
                    case_lines.append(f"        result.{param_name} = data ? data.slice({2 + data_offset * 64}, {66 + data_offset * 64}) : null;")
                data_offset += 1
        
        case_lines.append("        break;")
        decode_cases.append("\n".join(case_lines))
    
    decode_cases_str = "\n".join(decode_cases)
    
    # Generate the complete function
    function_sql = f"""
-- Auto-generated decode function for {event_type} events
CREATE OR REPLACE FUNCTION `{project_id}.{dataset_id}.{function_name}`(
  data STRING,
  topics ARRAY<STRING>
)
RETURNS STRUCT<
  {return_struct}
>
LANGUAGE js AS \"\"\"
  if (!topics || topics.length === 0) {{
    return {{ decoded: false, event_name: null }};
  }}
  
  const eventSignature = topics[0];
  
  // {event_type.title()} event signatures
  const eventSignatures = {{
{event_mappings_str}
  }};
  
  const eventName = eventSignatures[eventSignature];
  if (!eventName) {{
    return {{ decoded: false, event_name: null }};
  }}
  
  try {{
    let result = {{ decoded: true, event_name: eventName }};
    
    switch (eventName) {{
{decode_cases_str}
    }}
    
    return result;
  }} catch (e) {{
    return {{ decoded: false, event_name: eventName }};
  }}
\"\"\";

-- Create decoded events table using the function
CREATE OR REPLACE TABLE `{project_id}.{dataset_id}.decoded_{event_type}_events` AS
SELECT 
  *,
  `{project_id}.{dataset_id}.{function_name}`(data, topics) AS decoded_event
FROM `{project_id}.{dataset_id}.ens_raw_{event_type}_events`
WHERE `{project_id}.{dataset_id}.{function_name}`(data, topics).decoded = true;
"""
    
    return function_sql

def convert_solidity_to_bq_type(solidity_type):
    """Convert Solidity types to BigQuery types"""
    type_mapping = {
        'bytes32': 'BYTES',
        'bytes': 'BYTES', 
        'address': 'STRING',
        'string': 'STRING',
        'uint256': 'INT64',
        'uint64': 'INT64',
        'uint32': 'INT64',
        'bool': 'BOOL',
        'bytes4': 'BYTES',
        'uint256[]': 'ARRAY<INT64>',
        'bytes[]': 'ARRAY<BYTES>'
    }
    return type_mapping.get(solidity_type, 'STRING')

def main():
    # Load the event definitions
    with open('../data/event_definition_with_properties.yml', 'r') as f:
        config = yaml.safe_load(f)
    
    contracts = config['contracts']
    
    # Get unique event types
    event_types = set()
    for contract in contracts:
        event_types.add(contract['event_type'])
    
    # Generate functions for each event type
    for event_type in sorted(event_types):
        print(f"-- Generating decode function for {event_type} events")
        function_sql = generate_decode_function(event_type, contracts)
        
        # Write to file
        filename = f"decode_{event_type}_events.sql"
        with open(filename, 'w') as f:
            f.write(function_sql)
        
        print(f"Created {filename}")

if __name__ == "__main__":
    main()