# oc-amd

## this script is delivered “as is” and I deny any and all liability for any damages arising out of using this script

ideally place in the /opt folder

`cd /opt`

`git clone https://github.com/Acktarius/oc-amd.git`

`cd oc-amd`

`sudo chmod 755 oc-amd.sh`


oc-amd is a bash script which can be launch as a service to setup overclock pre mining operation.

`sudo ./oc-amd.sh`

the value the oc_start.txt file will be used to set performance mode, pl, mem , fan

## Exemple
`./oc-amd.sh`

when done:
`./oc-amd.sh reset`


CCX-mining.service.template is provided as a guide on how to insert the command to start and reset OC.
