#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2025, Acktarius
######################################

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEVICES_JSON="${SCRIPT_DIR}/devices.json"

#trip
trip() {
kill -INT $$
}

# Check if devices.json exists
if [ ! -f "$DEVICES_JSON" ]; then
    echo "Error: devices.json not found at $DEVICES_JSON"
    exit 1
fi

device="$1"
revision="$2"

# Get card name from JSON using jq
card=$(jq -r --arg dev "$device" --arg rev "$revision" '
    if has($dev) then
        .[$dev].revision[$rev] // "unknown"
    else
        "unknown"
    end
' "$DEVICES_JSON")

echo "$card"
