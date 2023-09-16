#!/bin/bash
#regulate GPU temp
# this file is subject to Licence
#Copyright (c) 2023, Acktarius
##################################################################
case "$TERM" in
        xterm-256color)
        WHITE=$(tput setaf 7 bold)
        ORANGE=$(tput setaf 202)
        GRIS=$(tput setaf 245)
	LINK=$(tput setaf 4 smul)
        TURNOFF=$(tput sgr0)
        ;;
        *)
        WHITE=''
	ORANGE=''
        GRIS=''
	LINK=''
        TURNOFF=''
        ;;
esac

# get path to card
path2card=$(readlink -f /sys/class/drm/card0/device)
device=$(cat ${path2card}/device)
testgpu=$(glxinfo | grep -c "RX 6400")
if [[ "$device" != "0x743f" ]] || [[ $testgpu -lt 1 ]]; then

echo "your gpu doesn't seem to be a RX 6400"
sleep 2
exit

else

#get actual edge temp
gput=$(sensors | grep "edge" | cut -d "+" -f 2 | cut -d "." -f 1)
echo -e "actual gpu edge temperature is ${ORANGE}${gput}${TURNOFF}"
#fan present mining setting
fspeed=$(cat ${path2card}/hwmon/hwmon*/pwm1)
fspeedoc=$(cat /opt/conceal-toolbox/oc-amd/oc_start.txt | grep 'fspeed' | cut -d " " -f 3)
fmax=$(cat ${path2card}/hwmon/hwmon*/pwm1_max)
fmode=$(cat ${path2card}/hwmon/hwmon*/pwm1_enable)

#presentation
clear
echo -e "${GRIS}###############################################################################"
echo -e "${GRIS}##################                       ######################################"
echo -e "${GRIS}#################${WHITE}  CCX-BOX gpu fan speed  ${GRIS}#####################################"
echo -e "${GRIS}##################                       ######################################"
echo -e "${GRIS}###############################################################################"
echo -e "${GRIS}###############################################################      .::::."
echo -e "#                                                                .:---=--=--::."
echo -e "#${WHITE} This script will help you to implement a fan speed,${GRIS}    \t -=:+-.  .-=:=:"
echo -e "#${WHITE} either directly or via a target temperature.${GRIS}     \t\t -=:+."
echo -e "#${WHITE} And to apply it (or not) in overclock settings. ${GRIS}  \t\t -=:+."
echo -e "#                                                           \t -=:+."
echo -e "#${WHITE} present edge temp ${ORANGE}${gput}${GRIS}        \t\t\t\t\t -=:=."
echo -e "#${WHITE} present fan speed: ${ORANGE}${fspeed}${WHITE} / ${fmax}${GRIS}    \t\t\t\t -+:-:    .::."
echo -e "#${WHITE} fan speed in overclock settings: ${ORANGE}${fspeedoc}${WHITE} / ${fmax}${GRIS}    \t\t -+==------===-"
echo -e "###############################################################\t    :-=-==-:\n"

#Function
implement () {
implementation=$(zenity --list --radiolist --height 280 --width 400 --title "Confirm and Select an option" \
--column "Select" --column "Option" \
TRUE "just for now" \
FALSE "for now and next boot")

case "$implementation" in
	"just for now")
echo $1 > ${path2card}/hwmon/hwmon*/pwm1
echo -e "${ORANGE}${1}${TURNOFF} as been applied just for this session"
sleep 2
exit
	;;
	"for now and next boot")
echo $1 > ${path2card}/hwmon/hwmon*/pwm1
echo "$(awk -v new="$1" '$1 ~ /fspeed$/ {$3 = new}1' /opt/conceal-toolbox/oc-amd/oc_start.txt)" > /opt/conceal-toolbox/oc-amd/oc_start.txt
echo -e "${ORANGE}${1}${TURNOFF} as been applied and recorded in overclock parameters"
	;;
	*)
echo -e "nothing will be done${TURNOFF}"
sleep 2
exit
	;;
esac

}


#verification fan in  manual mode
if [[ "$fmode" = "1" ]]; then 

echo -e "${TURNOFF}Implementation of a fan speed value ${WHITE}D${TURNOFF}irectly or via ${WHITE}T${TURNOFF}arget temperature (${WHITE}D${TURNOFF}/${WHITE}T${TURNOFF})?${WHITE}"
read answer

case "$answer" in
        [dD])
#question
echo -e "${GRIS}which fan speed would you like, between: 125 to ${fmax}?${ORANGE} below 125 at your own risk !${WHITE}"
read fspeedn
if [[ $fspeedn =~ ^[0-9]+$ ]] && (( ${fspeedn} > 124 )) && (( ${fspeedn} < ${fmax} )); then

implement ${fspeedn}
# less than 125
elif [[ $fspeedn =~ ^[0-9]+$ ]] && (( ${fspeedn} > 0 )) && (( ${fspeedn} < 125 )); then
zenity --warning --title "CONFIRM TO PROCEED" --width 400 --height 80 --text "Implement ${fspeedn}  ... at your own risk ?"
sleep 1
implement ${fspeedn}

else
echo -e "${ORANGE}Incorrect Value${TURNOFF} nothing has been done"
fi
	;;
	[tT])

read -p "${GRIS}what is your target temperature? ${WHITE}" target

if ! [[ $target =~ ^[0-9]+$ ]]; then
   echo -e "${ORANGE}error: Not a number${TURNOFF}" >&2; exit 1
fi

if (( $target >= $gput )); then
echo "${TURNOFF}nothing will be done"
sleep 1
else
echo -e "${GRIS}this process will take 3 minutes${TURNOFF}"
	#loop fibonacci
	for t in 0 10 20 30 50 80; do
	sleep $t
	gput=$(sensors | grep "edge" | cut -d "+" -f 2 | cut -d "." -f 1)
	fspeed=$(cat ${path2card}/hwmon/hwmon*/pwm1)
	echo "present fan speed: ${fspeed}"
	if [[ "${gput}" > $target ]]; then
	deltatf=$(( ($gput - $target) * 15 ))
	fspeedx=$(( $fspeed + $deltatf ))
	if [[ ${fspeedx} > 250 ]]; then
		fspeedx=250
	fi

	if [[ $t -gt 0 ]]; then
	j=$(( $t/5 ))
	for (( i=0; i <= $j; i++ )); do echo -n -e "${GRIS}."; done
	echo -e "${GRIS}after ${t} seconds${TURNOFF}"
	fi

	echo "${TURNOFF}edge temperature is ${WHITE}$gput${TURNOFF} and fan speed is ${WHITE}${fspeedx}${TURNOFF}/255 "
	echo $fspeedx > ${path2card}/hwmon/hwmon*/pwm1
	fi
	done


echo "${GRIS}final fan speed value for target temperature: ${WHITE}${fspeedx}${GRIS} is set.${TURNOFF}"
echo -e "${GRIS}Would you like to implement fan speed at next miner restart ? (${WHITE}Y${TURNOFF}/${WHITE}n)";
read answer2
case "$answer2" in
	[yY])
	echo "$(awk -v new="$fspeedx" '$1 ~ /fspeed$/ {$3 = new}1' /opt/conceal-toolbox/oc-amd/oc_start.txt)" > /opt/conceal-toolbox/oc-amd/oc_start.txt
	;;
	[nN])
echo "${TURNOFF}fan speed will remain default back at nex boot"
	;;
	*)
echo -e "${ORANGE}invalid answer, nothing will be done${TURNOFF}"
fspeed=$(cat /opt/conceal-toolbox/oc-amd/oc_start.txt | grep 'fspeed' | cut -d " " -f 3)
echo $fspeed > ${path2card}/hwmon/hwmon*/pwm1
	;;
esac
fi
	;;
	*)
echo -e "${GRIS}unvalid answer.${TURNOFF} Bye, now !" >&2; exit 1
	;;
esac

else
echo -e "${GRIS}fan has to be in manual mode to have this script running,\nconsider coming back when mining.${TURNOFF} Bye, now !"
sleep 2
fi
exit

fi
