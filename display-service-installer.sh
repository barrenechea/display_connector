#!/bin/bash

sudo rm -rf ~/display_connector/venv
rm -rf ~/display_connector/__pycache__
# Run the first script
~/display_connector/display-env-install.sh

# Define the service file path, script path, and log file path
OLD_SERVICE_FILE="/etc/systemd/system/OpenNept4une.service"
SERVICE_FILE="/etc/systemd/system/display.service"
SCRIPT_PATH="$HOME/display_connector/display.py"
VENV_PATH="$HOME/display_connector/venv"
LOG_FILE="/var/log/display.log"
MOONRAKER_ASVC="$HOME/printer_data/moonraker.asvc"

# Check if the script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Script $SCRIPT_PATH not found."
    exit 1
fi

# Check if the old service exists and is running
if systemctl is-active --quiet OpenNept4une; then
    # Stop the service silently
    sudo service OpenNept4une stop >/dev/null 2>&1
    # Disable the service silently
    sudo service OpenNept4une disable >/dev/null 2>&1
    sudo rm -f $OLD_SERVICE_FILE
else
    echo "Continuing..."
fi

if systemctl is-active --quiet display; then
    # Stop the service silently
    sudo service display stop >/dev/null 2>&1
else
    echo "Continuing..."
fi

# Create the systemd service file 
echo "Creating systemd service file at $SERVICE_FILE..."
cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=OpenNept4une TouchScreen Display Service
After=klipper.service klipper-mcu.service moonraker.service
Wants=klipper.service moonraker.service
Documentation=man:display(8)

[Service]
ExecStartPre=/bin/sleep 10
ExecStart=/home/mks/display_connector/venv/bin/python /home/mks/display_connector/display.py
WorkingDirectory=/home/mks/display_connector
Restart=on-failure
CPUQuota=50%
RestartSec=10
User=mks
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to read new service file
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl enable display.service
sudo systemctl start display.service

echo "Allowing Moonraker to control display service"
grep -qxF 'display' $MOONRAKER_ASVC || echo 'display' >> $MOONRAKER_ASVC

# Define the lines to be inserted or updated
new_lines="[update_manager display]\n\
type: git_repo\n\
primary_branch: main\n\
path: ~/display_connector\n\
virtualenv: ~/display_connector/venv\n\
origin: https://github.com\/OpenNeptune3D/display.git"

# Define the path to the moonraker.conf file
config_file="$HOME/printer_data/config/moonraker.conf"

# Check if the lines exist in the config file
if grep -qF "[update_manager display]" "$config_file"; then
    # Lines exist, update them
    perl -pi.bak -e "BEGIN{undef $/;} s|\[update_manager display\].*?((?:\r*\n){2}\|$)|$new_lines\$1|gs" "$config_file"
else
    # Lines do not exist, append them to the end of the file
    echo -e "\n$new_lines" >> "$config_file"
fi

echo "Service setup complete."

sudo service moonraker restart 
