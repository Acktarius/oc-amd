#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2024, Acktarius

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TMP_FILE="/tmp/amd-oc-status.tmp"

# Function to handle reset
handle_reset() {
    local script_used=$(cat "$TMP_FILE" | cut -d'|' -f2)
    local status=$(cat "$TMP_FILE" | cut -d'|' -f3)
    
    if [ "$status" = "success" ]; then
        if zenity --question \
            --title="Reset Overclock" \
            --text="Overclock is currently active.\nWould you like to reset it?" \
            --ok-label="Yes, Reset" \
            --cancel-label="No, Keep OC"; then
            
            case "$script_used" in
                "oc-amd.sh")
                    pkexec "${SCRIPT_DIR}/oc-amd.sh" reset
                    ;;
                "oc-amd-rig.sh")
                    pkexec "${SCRIPT_DIR}/oc-amd-rig.sh" reset
                    ;;
            esac
            
            # Remove tmp file after reset
            rm -f "$TMP_FILE"
            zenity --info --text="Overclock has been reset." --timeout=8
        fi
        exit 0
    fi
}

# Check if there's an active OC session
if [ -f "$TMP_FILE" ]; then
    handle_reset
fi

# Ask user which script to run using zenity
choice=$(zenity --list \
    --title="AMD GPU Overclock" \
    --text="Choose overclock mode:" \
    --radiolist \
    --column="Select" --column="Mode" \
    TRUE "OC for first Card Found" \
    FALSE "OC for the Mining Rig")

case "$choice" in
    "OC for first Card Found")
        script_name="oc-amd.sh"
        ;;
    "OC for the Mining Rig")
        script_name="oc-amd-rig.sh"
        ;;
    *)
        zenity --error --text="No option selected, exiting."
        exit 1
        ;;
esac 

# Execute the selected script
if pkexec "${SCRIPT_DIR}/${script_name}"; then
    echo "$$|${script_name}|success" > "$TMP_FILE"
    zenity --info --text="Overclock applied successfully!"
else
    echo "$$|${script_name}|failed" > "$TMP_FILE"
    zenity --error --text="Failed to apply overclock."
    exit 1
fi