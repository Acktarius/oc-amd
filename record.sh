#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2025, Acktarius

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Source shared functions
source "${SCRIPT_DIR}/functions.sh"

# Get list of supported devices
get_supported_devices

# Colors for different cards (using distinct colors)
COLORS=("#FF0000" "#00FF00" "#0000FF" "#FF00FF" "#00FFFF" "#FFFF00" "#FF8000" "#8000FF" "#00FF80" "#FF0080")

# Initialize arrays for data collection
declare -A gpu_busy
declare -A fan_speed
declare -A power_usage
declare -A card_names
declare -A device_indices

# Function to get path to card
path2card() {
    echo $(readlink -f "/sys/class/drm/card${1}/device")
}

# Function to find correct hwmon directory
get_hwmon_dir() {
    local card_path="$1"
    
    # Check hwmon1 first
    if [[ -d "${card_path}/hwmon/hwmon1" ]]; then
        echo "${card_path}/hwmon/hwmon1"
    # Then check hwmon2
    elif [[ -d "${card_path}/hwmon/hwmon2" ]]; then
        echo "${card_path}/hwmon/hwmon2"
    else
        echo ""
    fi
}

# Find initial card
for ((card_num=0; card_num<=2; card_num++)); do
    initialCardPath="/sys/class/drm/card${card_num}/device"
    if [ -d "${initialCardPath}" ]; then
        cardInit=$card_num
        break
    fi
done

# Initialize data collection arrays
timestamp=$(date +%Y%m%d_%H%M%S)

# Create records directory if it doesn't exist
records_dir="${SCRIPT_DIR}/records"
if [[ ! -d "$records_dir" ]]; then
    mkdir -p "$records_dir"
fi

# Create debug log file
debug_log="${records_dir}/debug_${timestamp}.log"
echo "Debug log for recording session ${timestamp}" > "$debug_log"
echo "----------------------------------------" >> "$debug_log"

card_count=0

# Collect data for 1 minute at 5-second intervals
total_time=60
echo "Recording GPU metrics for ${total_time} seconds..."
for ((t=0; t<12; t++)); do
    # Loop through cards
    for ((i = cardInit; i < 10; i++)); do
        pathToCard=$(path2card $i)
        if [[ ! -d ${pathToCard} ]]; then
            continue
        fi
        
        device=$(cat "${pathToCard}/device")
        if [[ ! "${device}" =~ ^(${supported_devices})$ ]]; then
            continue
        fi

        # Get card name if not already stored
        if [[ -z "${card_names[$i]}" ]]; then
            revision=$(cat "${pathToCard}/revision" 2>/dev/null || echo "null")
            card_names[$i]=$(source ${SCRIPT_DIR}/check_device.sh $device $revision)
            device_indices[$i]=$card_count
            ((card_count++))
        fi

        # Collect metrics
        # Get correct hwmon directory for this card
        hwmon_dir=$(get_hwmon_dir "${pathToCard}")

        # Log raw values for debugging
        echo "Time: $((t*5))s, Card: ${card_names[$i]}" >> "$debug_log"
        echo "  GPU busy: $(cat "${pathToCard}/gpu_busy_percent" 2>/dev/null || echo "ERROR")" >> "$debug_log"
        if [[ -n "$hwmon_dir" ]]; then
            echo "  Fan speed: $(cat "${hwmon_dir}/pwm1" 2>/dev/null || echo "ERROR")" >> "$debug_log"
            echo "  Power usage: $(cat "${hwmon_dir}/power1_average" 2>/dev/null || echo "ERROR")" >> "$debug_log"
        else
            echo "  Fan speed: ERROR (no hwmon1 or hwmon2 directory found)" >> "$debug_log"
            echo "  Power usage: ERROR (no hwmon1 or hwmon2 directory found)" >> "$debug_log"
        fi
        echo "----------------------------------------" >> "$debug_log"

        gpu_busy[$i,$t]=$(cat "${pathToCard}/gpu_busy_percent" 2>/dev/null || echo "0") || gpu_busy[$i,$t]=0
        if [[ -n "$hwmon_dir" ]]; then
            fan_speed[$i,$t]=$(cat "${hwmon_dir}/pwm1" 2>/dev/null || echo "0") || fan_speed[$i,$t]=0
            power_usage[$i,$t]=$(cat "${hwmon_dir}/power1_average" 2>/dev/null || echo "0") || power_usage[$i,$t]=0
        else
            fan_speed[$i,$t]=0
            power_usage[$i,$t]=0
        fi
    done
    
    # Wait 5 seconds before next collection and show countdown
    if [[ $t -lt 11 ]]; then
        time_left=$((total_time - (t+1)*5))
        echo -ne "\rTime remaining: ${time_left} seconds...   "
        sleep 5
    fi
done
echo -e "\nRecording complete. Generating chart..."

# Generate gnuplot script for visualization
cat > /tmp/plot.gnu << EOF
set terminal pngcairo size 1200,800 enhanced font 'Arial,12'
set output '${records_dir}/record_${timestamp}.png'
set title 'GPU Metrics Record on $(date)' font 'Arial,14'
set xlabel 'Time (seconds)'
set ylabel 'GPU Usage / Fan Speed (%)'
set yrange [0:100]
set y2label 'Power (W)'
set y2range [0:350]
set y2tics
set grid
set key below center Left reverse
set key samplen 2 spacing 1.5 height 2

# Plot data
plot \\
EOF

# Generate data files and plot commands for each metric
for ((i = cardInit; i < 10; i++)); do
    if [[ -n "${card_names[$i]}" ]]; then
        color=${COLORS[${device_indices[$i]}]}
        
        # Create temporary data file with scaled values
        datafile="/tmp/card${i}_data.txt"
        for ((t=0; t<12; t++)); do
            echo "$((t*5)) ${gpu_busy[$i,$t]} ${fan_speed[$i,$t]} ${power_usage[$i,$t]}" >> "$datafile"
        done

        # Add plot commands with appropriate axes
        echo "'/tmp/card${i}_data.txt' using 1:2 title '${card_names[$i]} GPU%' with lines lw 2 lc rgb '${color}', \\" >> /tmp/plot.gnu
        echo "'/tmp/card${i}_data.txt' using 1:(\$3*100.0/255.0) title '${card_names[$i]} Fan%' with lines lw 2 lc rgb '${color}' dt 2, \\" >> /tmp/plot.gnu
        echo "'/tmp/card${i}_data.txt' using 1:(\$4/1000000.0) title '${card_names[$i]} Power (W)' with lines lw 2 lc rgb '${color}' dt 3 axes x1y2, \\" >> /tmp/plot.gnu
    fi
done

# Remove trailing comma and backslash
sed -i '$ s/,\s*\\$//' /tmp/plot.gnu

# Generate plot
gnuplot /tmp/plot.gnu

# Cleanup temporary files
rm -f /tmp/card*_data.txt /tmp/plot.gnu

echo "Recording complete. Chart saved as records/record_${timestamp}.png" 