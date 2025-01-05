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
        gpu_busy[$i,$t]=$(cat "${pathToCard}/gpu_busy_percent" 2>/dev/null || echo "0")
        fan_speed[$i,$t]=$(cat "${pathToCard}/hwmon/hwmon*/pwm1" 2>/dev/null || echo "0")
        power_usage[$i,$t]=$(cat "${pathToCard}/hwmon/hwmon*/power1_average" 2>/dev/null || echo "0")
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
set output '${SCRIPT_DIR}/record_${timestamp}.png'
set title 'GPU Metrics Record on $(date)' font 'Arial,14'
set xlabel 'Time (seconds)'
set ylabel 'GPU Usage (%)'
set yrange [0:100]
set y2label 'Fan Speed / Power'
set y2range [0:350]
set y2tics
set grid
set key below

# Define scaling factors
fan_scale = 100.0/255.0  # Convert 0-255 to 0-100%
power_scale = 1.0/1000000.0  # Convert µW to W

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
            echo "$((t*5)) ${gpu_busy[$i,$t]} $( echo "scale=2; ${fan_speed[$i,$t]}*$fan_scale" | bc) $(echo "scale=2; ${power_usage[$i,$t]}*$power_scale" | bc)" >> "$datafile"
        done

        # Add plot commands with appropriate axes
        echo "'/tmp/card${i}_data.txt' using 1:2 title '${card_names[$i]} GPU%' with lines lw 2 lc rgb '${color}', \\" >> /tmp/plot.gnu
        echo "'/tmp/card${i}_data.txt' using 1:3 title '${card_names[$i]} Fan%' with lines lw 2 lc rgb '${color}' dt 2 axes x1y1, \\" >> /tmp/plot.gnu
        echo "'/tmp/card${i}_data.txt' using 1:4 title '${card_names[$i]} Power(W)' with lines lw 2 lc rgb '${color}' dt 3 axes x1y2, \\" >> /tmp/plot.gnu
    fi
done

# Remove trailing comma and backslash
sed -i '$ s/,\s*\\$//' /tmp/plot.gnu

# Generate plot
gnuplot /tmp/plot.gnu

# Cleanup temporary files
rm -f /tmp/card*_data.txt /tmp/plot.gnu

echo "Recording complete. Chart saved as record_${timestamp}.png" 