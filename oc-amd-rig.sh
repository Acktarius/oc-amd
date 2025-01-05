#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2025, Acktarius
####################################
#test card is a RX6400
#glxinfo doesn't work when called from a service
#testgpu=$(glxinfo | grep -c "RX 6400")
# Variables and functions

#declaration variables and functions
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Source shared functions
source "${SCRIPT_DIR}/functions.sh"

# Get list of supported devices
get_supported_devices

#trip
trip() {
kill -INT $$
}
#Initial Card
for ((card_num=0; card_num<=2; card_num++)); do
    initialCardPath="/sys/class/drm/card${card_num}/device"
    if [ -d "${initialCardPath}" ]; then
        cardInit=$card_num
        break
    fi
    if [ $card_num -eq 2 ]; then
        echo "Error: No GPU device directory found (checked card0, card1, card2)"
        exit 1
    fi
done



# get path to card
path2card() {
echo $(readlink -f "/sys/class/drm/card${1}/device")
}

# loop through cards
for ((i = $cardInit ; i < 10 ; i++)); do
    pathToCard=$(path2card $i)
    if [[ ! -d ${pathToCard} ]]; then
        break
    fi
    device=$(cat "${pathToCard}/device")        
            case "${device}" in
                ${supported_devices})
                    # These are the devices we want to process
                    ;;
                *)
                    echo "Skipping card${i}: unsupported device ID ${device}"
                    continue
                    ;;
            esac  
        revision=$(cat "${pathToCard}/revision" 2>/dev/null || echo "null")
        card=$(source ${SCRIPT_DIR}/check_device.sh $device $revision)
        ocFile="oc_start_${card}.txt"
        #check oc file exist
        if [[ ! -f "$ocFile" ]]; then
        echo "Error: No overclock file found for card${i}: ${card}"
        else
            # oc or reset ?
            case "$1" in
                reset|R)

            #set power to default ------------------------------------------------------------------- < reset
            pldefault=$(cat ${pathToCard}/hwmon/hwmon*/power1_cap_default)
            echo $pldefault > ${pathToCard}/hwmon/hwmon*/power1_cap
            #set fan auto
            echo 2 > ${pathToCard}/hwmon/hwmon*/pwm1_enable
            #Set performance to auto
            echo "auto" > ${pathToCard}/power_dpm_force_performance_level
            echo -e "card${i} : ${card} overclocks reset" 
		 ;;
                *)
            #set  Performance to manual ------------------------------------------------------------- < over-clocking
            echo "manual" > ${pathToCard}/power_dpm_force_performance_level

            #set power
            pl="$(cat $ocFile | grep 'pl' | cut -d " " -f 3)000000"
            minpl=$(cat ${pathToCard}/hwmon/hwmon*/power1_cap_min)
            maxpl=$(cat ${pathToCard}/hwmon/hwmon*/power1_cap_max)
            if (( $pl >= $minpl )) && (( $pl <= $maxpl )); then
                echo "$pl" > ${pathToCard}/hwmon/hwmon*/power1_cap
            else
                echo "Warning: Power limit $pl is outside allowed range ($minpl - $maxpl) for card${i}"
            fi
            #set power profile
            #get index value of profile mode
            profile=$(cat $ocFile | grep 'profile' | cut -d " " -f 3)
            mode=$(cat ${pathToCard}/pp_power_profile_mode | grep $profile | tr -s " " | cut -d " " -f 2)
            if [[ "$profile" != "CUSTOM" ]]; then 
	            if  [[ "$mode" =~ ^[0-9]+$ ]]; then
                echo $mode > ${pathToCard}/pp_power_profile_mode
                fi
	     # CUSTOM selected, injection of Base clock and boost
	    else
            declare -a neutral
            neutral=($(source ${SCRIPT_DIR}/getPPppm.sh ${pathToCard}))
            neutral[4]=$(cat $ocFile | grep 'baseCclk' | cut -d " " -f 3)
            neutral[6]=$(cat $ocFile | grep 'boostCclk' | cut -d " " -f 3)
            echo "6 ${neutral[@]}" > ${pathToCard}/pp_power_profile_mode
            unset neutral
	    fi
            
            #OS_SCLK
            if [ -f "${pathToCard}/pp_od_clk_voltage" ]; then
                odsclk=$(cat $ocFile | grep 'odsclk' | cut -d " " -f 3)
                echo "s 1 ${odsclk}" >  ${pathToCard}/pp_od_clk_voltage
                #VDD_OFFSET
                vo=$(cat $ocFile | grep 'vo' | cut -d " " -f 3)
                echo "vo ${vo}" >  ${pathToCard}/pp_od_clk_voltage
                #COMMIT PP_OD_CLK_VOLTAGE
                echo "c" >  ${pathToCard}/pp_od_clk_voltage
            else
                echo "Warning: pp_od_clk_voltage not available for card${i}: ${card}, skipping voltage offset"
            fi

            #set value for core clock
            sclk=$(cat $ocFile | grep 'Sclk' | cut -d " " -f 3)
            echo "${sclk}" > ${pathToCard}/pp_dpm_sclk
            #set value for mem
            mclk=$(cat $ocFile | grep 'mclk' | cut -d " " -f 3)

            #set fan manual
            fmode=$(cat $ocFile | grep 'fmode' | cut -d " " -f 3)
            echo $fmode > ${pathToCard}/hwmon/hwmon*/pwm1_enable
            #set fan speed
            fspeed=$(cat $ocFile | grep 'fspeed' | cut -d " " -f 3)
            echo $fspeed > ${pathToCard}/hwmon/hwmon*/pwm1    
	    echo  -e "oc applied to card${i} : ${card} \n"
     		
                ;;
            esac
        fi
done
