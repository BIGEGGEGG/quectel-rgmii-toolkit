#!/bin/bash

# Define constants
GITUSER="SunyWait"
GITTREE="development"
DIR_NAME="tailscale"
SERVICE_FILE="/lib/systemd/system/install_tailscale.service"
SERVICE_NAME="install_tailscale"
TMP_SCRIPT="/tmp/install_tailscale.sh"
LOG_FILE="/tmp/install_sshd.log"
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/bin:/opt/sbin:/usrdata/root/bin

# Tmp Script dependent constants 
TAILSCALE_DIR="/usrdata/tailscale/"
TAILSCALE_SYSD_DIR="/usrdata/tailscale/systemd"
# Function to remount file system as read-write
remount_rw() {
    mount -o remount,rw /
}

# Function to remount file system as read-only
remount_ro() {
    mount -o remount,ro /
}

# Installation Prep
remount_rw
systemctl daemon-reload
rm $SERVICE_FILE > /dev/null 2>&1
rm $SERVICE_NAME > /dev/null 2>&1

# Create the systemd service file
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Update $DIR_NAME temporary service

[Service]
Type=oneshot
ExecStart=/bin/bash $TMP_SCRIPT > $LOG_FILE 2>&1

[Install]
WantedBy=multi-user.target
EOF

# Create and populate the temporary shell script for installation
cat <<EOF > "$TMP_SCRIPT"
#!/bin/bash

export HOME=/usrdata/root
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/bin:/opt/sbin:/usrdata/root/bin
GITUSER="SunyWait"
GITTREE="development"
TAILSCALE_DIR="/usrdata/tailscale/"
TAILSCALE_SYSD_DIR="/usrdata/tailscale/systemd"

# Function to remount file system as read-write
remount_rw() {
    mount -o remount,rw /
}

# Function to remount file system as read-only
remount_ro() {
    mount -o remount,ro /
}

install_update_tailscale() {
    echo "Checking if Tailscale is already installed..."
    if [ -f "$TAILSCALE_DIR/tailscale" ]; then
        echo "Tailscale binary found. Updating Tailscale..."
        ln -sf "$TAILSCALE_DIR/tailscale" "/usrdata/root/bin/tailscale"
        echo y | $TAILSCALE_DIR/tailscale update
        echo -e "\e[32mTailscale updated!\e[0m"
	remount_ro
        exit 0
    else
        echo "Installing Tailscale..."
        mkdir -p "$TAILSCALE_DIR" "$TAILSCALE_SYSD_DIR"
        echo "Downloading binary files..."
        cd /usrdata
        curl -O https://pkgs.tailscale.com/stable/tailscale_1.66.4_arm.tgz
        tar -xzf tailscale_1.66.4_arm.tgz
		rm tailscale_1.66.4_arm.tgz
        cd /usrdata/tailscale_1.66.4_arm
        mv tailscale tailscaled "$TAILSCALE_DIR/"
        rm -rf /usrdata/tailscale_1.66.4_arm
        echo "Downloading systemd files..."
        cd "$TAILSCALE_SYSD_DIR"
        wget https://raw.gitmirror.com/$GITUSER/quectel-rgmii-toolkit/main/tailscale/systemd/tailscaled.service
        wget https://raw.gitmirror.com/$GITUSER/quectel-rgmii-toolkit/main/tailscale/systemd/tailscaled.defaults
        sleep 2s
        echo "Setting Permissions..."
        chmod +x "$TAILSCALE_DIR/tailscaled" "$TAILSCALE_DIR/tailscale"
        echo "Copying systemd units..."
        cp -rf "$TAILSCALE_SYSD_DIR"/* /lib/systemd/system/
        ln -sf /lib/systemd/system/tailscaled.service /lib/systemd/system/multi-user.target.wants/
        systemctl daemon-reload
        echo "Starting Tailscaled..."
        systemctl start tailscaled
        cd /
        remount_ro
        echo -e "\e[32mTailscale installed successfully.\e[0m"
		exit 0
    fi
}

# Execute the function
install_update_tailscale
exit 0
EOF

# Make the temporary script executable
chmod +x "$TMP_SCRIPT"

# Reload systemd to recognize the new service and start the update
systemctl daemon-reload
systemctl start $SERVICE_NAME
