#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2025, Acktarius

# Generate list of supported devices based on available OC files and devices.json
get_supported_devices() {
    local DEVICES_JSON="${SCRIPT_DIR}/devices.json"
    # Get all oc_start files in directory
    local oc_files=(${SCRIPT_DIR}/oc_start_*.txt)
    # Extract card names from filenames
    local available_cards=()
    for file in "${oc_files[@]}"; do
        available_cards+=($(basename "$file" .txt | sed 's/oc_start_//'))
    done
    
    # Create pattern for jq to match against
    local cards_pattern=$(IFS='|'; echo "${available_cards[*]}")
    
    # Query devices.json to get matching device IDs
    supported_devices=$(jq -r --arg pattern "$cards_pattern" '
        to_entries[] | 
        select(.value.revision | to_entries[] | 
            .value | match($pattern)
        ) | "\"" + .key + "\""
    ' "$DEVICES_JSON" | tr '\n' '|' | sed 's/|$//')
} 