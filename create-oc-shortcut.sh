#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2024, Acktarius

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    zenity --error \
        --title="Root Privileges Required" \
        --text="This script needs to be run as root.\n\nPlease run:\nsudo $0"
    exit 1
fi

# Get the actual user who ran the script with sudo
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Create desktop entry
cat > "${REAL_HOME}/Desktop/amd-oc-launcher.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AMD GPU OC
Comment=AMD GPU Overclock Utility
Exec=${SCRIPT_DIR}/oc-launcher.sh
Icon=${SCRIPT_DIR}/icon/oc-amd.png
Terminal=false
Categories=System;Settings;
EOF

# Make the desktop entry executable
chmod +x "${REAL_HOME}/Desktop/amd-oc-launcher.desktop"

# Make the launcher script executable
chmod +x "${SCRIPT_DIR}/oc-launcher.sh"

# Create polkit policy file
cat > /usr/share/polkit-1/actions/org.acktarius.amdoc.policy << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.acktarius.amdoc">
    <description>Run AMD GPU Overclock Scripts</description>
    <message>Authentication is required to run AMD GPU overclock scripts</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">${SCRIPT_DIR}/oc-amd.sh</annotate>
    <annotate key="org.freedesktop.policykit.exec.path">${SCRIPT_DIR}/oc-amd-rig.sh</annotate>
  </action>
</policyconfig>
EOF

# Fix ownership of the desktop file to the actual user
chown ${REAL_USER}:${REAL_USER} "${REAL_HOME}/Desktop/amd-oc-launcher.desktop"

zenity --info \
    --title="Setup Complete" \
    --text="Desktop shortcut created successfully!\nYou can now use the AMD GPU OC launcher from your desktop." 