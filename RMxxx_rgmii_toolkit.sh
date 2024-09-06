#!/bin/sh

# Define toolkit paths
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/bin:/opt/sbin:/usrdata/root/bin
GITUSER="BIGEGGEGG"
GITTREE="main"
TMP_DIR="/tmp"
USRDATA_DIR="/usrdata"
SOCAT_AT_DIR="/usrdata/socat-at-bridge"
SOCAT_AT_SYSD_DIR="/usrdata/socat-at-bridge/systemd_units"
SIMPLE_ADMIN_DIR="/usrdata/simpleadmin"
SIMPLE_FIREWALL_DIR="/usrdata/simplefirewall"
SIMPLE_FIREWALL_SCRIPT="$SIMPLE_FIREWALL_DIR/simplefirewall.sh"
SIMPLE_FIREWALL_SYSTEMD_DIR="$SIMPLE_FIREWALL_DIR/systemd"
TAILSCALE_DIR="/usrdata/tailscale"
TAILSCALE_SYSD_DIR="/usrdata/tailscale/systemd"
# AT Command Script Variables and Functions
DEVICE_FILE="/dev/smd7"
TIMEOUT=4  # Set a timeout for the response
# Function to remount file system as read-write
remount_rw() {
    mount -o remount,rw /
}

# Function to remount file system as read-only
remount_ro() {
    mount -o remount,ro /
}

# Basic AT commands without socat bridge for fast responce commands only
start_listening() {
    cat "$DEVICE_FILE" > /tmp/device_readout &
    CAT_PID=$!
}

send_at_command() {
    echo -e "\e[1;31m这仅适用于基本的快速响应指令!\e[0m"  # Red
    echo -e "\e[1;36m键入“install”，从现在开始只需在shell中键入atcmd\e[0m"
    echo -e "\e[1;36m已安装的版本比这个便携版本好得多\e[0m"
    echo -e "\e[1;32m请输入AT指令 (或输入 'exit' 来退出): \e[0m"
    read at_command
    if [ "$at_command" = "exit" ]; then
        return 1
    fi
    
    if [ "$at_command" = "install" ]; then
		install_update_at_socat
		echo -e "\e[1;32m已安装。从adb shell或ssh键入atcmd以启动AT命令会话\e[0m"
		return 1
    fi
    echo -e "${at_command}\r" > "$DEVICE_FILE"
}

wait_for_response() {
    local start_time=$(date +%s)
    local current_time
    local elapsed_time

    echo -e "\e[1;32m指令已发送，等待响应...\e[0m"
    while true; do
        if grep -qe "OK" -e "ERROR" /tmp/device_readout; then
            echo -e "\e[1;32m响应收到:\e[0m"
            cat /tmp/device_readout
            return 0
        fi
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
            echo -e "\e[1;31m错误：响应超时.\e[0m"  # Red
	    echo -e "\e[1;32m如果响应时间超过1秒或2秒，则此操作将不起作用\e[0m"  # Green
	    echo -e "\e[1;36m键入install以安装更好的版本.\e[0m"  # Cyan
            return 1
        fi
        sleep 1
    done
}

cleanup() {
    kill "$CAT_PID"
    wait "$CAT_PID" 2>/dev/null
    rm -f /tmp/device_readout
}

send_at_commands() {
    if [ -c "$DEVICE_FILE" ]; then
        while true; do
            start_listening
            send_at_command
            if [ $? -eq 1 ]; then
                cleanup
                break
            fi
            wait_for_response
            cleanup
        done
    else
        echo -e "\e[1;31m错误: 设备 $DEVICE_FILE 不存在!\e[0m"
    fi
}

# Check for existing Entware/opkg installation, install if 否t installed
ensure_entware_installed() {
	remount_rw
    if [ ! -f "/opt/bin/opkg" ]; then
        echo -e "\e[1;32m安装 Entware/OPKG\e[0m"
        cd /tmp && wget -O installentware.sh "https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/installentware.sh" && chmod +x installentware.sh && ./installentware.sh
        if [ "$?" -ne 0 ]; then
            echo -e "\e[1;31mEntware/OPKG 安装失败，请检查您的互联网连接或存储库URL。\e[0m"
            exit 1
        fi
        cd /
    else
        echo -e "\e[1;32mEntware/OPKG 安装完成。\e[0m"
        if [ "$(readlink /bin/login)" != "/opt/bin/login" ]; then
            opkg update && opkg install shadow-login shadow-passwd shadow-useradd
            if [ "$?" -ne 0 ]; then
                echo -e "\e[1;31mPackage 安装失败。请检查您的互联网连接，然后重试。\e[0m"
                exit 1
            fi

            # Replace the login and passwd binaries and set home for root to a writable directory
            rm /opt/etc/shadow
            rm /opt/etc/passwd
            cp /etc/shadow /opt/etc/
            cp /etc/passwd /opt/etc
            mkdir -p /usrdata/root/bin
            touch /usrdata/root/.profile
            echo "# Set PATH for all shells" > /usrdata/root/.profile
            echo "export PATH=/bin:/usr/sbin:/usr/bin:/sbin:/opt/sbin:/opt/bin:/usrdata/root/bin" >> /usrdata/root/.profile
            chmod +x /usrdata/root/.profile
            sed -i '1s|/home/root:/bin/sh|/usrdata/root:/bin/bash|' /opt/etc/passwd
            rm /bin/login /usr/bin/passwd
            ln -sf /opt/bin/login /bin
            ln -sf /opt/bin/passwd /usr/bin/
			ln -sf /opt/bin/useradd /usr/bin/
            echo -e "\e[1;31m请设置一个root密码。\e[0m"
            /opt/bin/passwd

            # Install basic and useful utilities
            opkg install mc htop dfc lsof
            ln -sf /opt/bin/mc /bin
            ln -sf /opt/bin/htop /bin
            ln -sf /opt/bin/dfc /bin
            ln -sf /opt/bin/lsof /bin
        fi

        if [ ! -f "/usrdata/root/.profile" ]; then
            opkg update && opkg install shadow-useradd
            mkdir -p /usrdata/root/bin
            touch /usrdata/root/.profile
            echo "# Set PATH for all shells" > /usrdata/root/.profile
            echo "export PATH=/bin:/usr/sbin:/usr/bin:/sbin:/opt/sbin:/opt/bin:/usrdata/root/bin" >> /usrdata/root/.profile
            chmod +x /usrdata/root/.profile
            sed -i '1s|/home/root:/bin/sh|/usrdata/root:/bin/bash|' /opt/etc/passwd
        fi
    fi
	if [ ! -f "/opt/sbin/useradd" ]; then
		echo "useradd 不存在，开始安装 shadow-useradd..."
		opkg install shadow-useradd
		else
		echo "useradd 已存在， 继续..."
	fi
    
	if [ ! -f "/usr/bin/curl" ] && [ ! -f "/opt/bin/curl" ]; then
        echo "curl 不存在，安装 curl..."
        opkg update && opkg install curl
        if [ "$?" -ne 0 ]; then
            echo -e "\e[1;31mcurl安装失败，请检查您的互联网连接，然后重试。\e[0m"
            exit 1
        fi
    else
        echo "curl 已安装，继续..."
    fi
}

#Uninstall Entware if the Users chooses 
uninstall_entware() {
    echo -e '\033[31mInfo: 开始Entware/OPKG卸载进程...\033[0m'

    # Stop services
    systemctl stop rc.unslung.service
    /opt/etc/init.d/rc.unslung stop
    rm /lib/systemd/system/multi-user.target.wants/rc.unslung.service
    rm /lib/systemd/system/rc.unslung.service
    
    systemctl stop opt.mount
    rm /lib/systemd/system/multi-user.target.wants/start-opt-mount.service
    rm /lib/systemd/system/opt.mount
    rm /lib/systemd/system/start-opt-mount.service

    # Unmount /opt if mounted
    mountpoint -q /opt && umount /opt

    # Remove Entware installation directory
    rm -rf /usrdata/opt
    rm -rf /opt

    # Reload systemctl daemon
    systemctl daemon-reload

    # Optionally, clean up any modifications to /etc/profile or other system files
    # Restore original link to login binary compiled by Quectel
    rm /bin/login
    ln /bin/login.shadow /bin/login

    echo -e '\033[32mInfo: Entware/OPKG 已被成功卸载。\033[0m'
}

# function to configure the fetures of simplefirewall
configure_simple_firewall() {
    if [ ! -f "$SIMPLE_FIREWALL_SCRIPT" ]; then
        echo -e "\033[0;31mSimplefirewall未安装，你想要安装它吗?\033[0m"
        echo -e "\033[0;32m1) 是\033[0m"
        echo -e "\033[0;31m2) 否\033[0m"
        read -p "输入选择(1-2): " install_choice

        case $install_choice in
            1)
                install_simple_firewall
                ;;
            2)
                return
                ;;
            *)
                echo -e "\033[0;31m无效选择， 请选择 1 或 2。\033[0m"
                ;;
        esac
    fi

    echo -e "\e[1;32m配置Simple Firewall:\e[0m"
    echo -e "\e[38;5;208m1) 配置传入端口块\e[0m"
    echo -e "\e[38;5;27m2) 配置TTL\e[0m"
    read -p "输入选择(1-2): " menu_choice

    case $menu_choice in
    1)
        # Original ports configuration code with exit option
        current_ports_line=$(grep '^PORTS=' "$SIMPLE_FIREWALL_SCRIPT")
        ports=$(echo "$current_ports_line" | cut -d'=' -f2 | tr -d '()' | tr ' ' '\n' | grep -o '[0-9]\+')
        echo -e "\e[1;32m当前配置的端口:\e[0m"
        echo "$ports" | awk '{print NR") "$0}'

        while true; do
            echo -e "\e[1;32m输入要添加/删除的端口号，或键入“完成”或“退出”以完成:\e[0m"
            read port
            if [ "$port" = "done" ] || [ "$port" = "exit" ]; then
                if [ "$port" = "exit" ]; then
                    echo -e "\e[1;31m正在退出而不进行更改...\e[0m"
                    return
                fi
                break
            elif ! echo "$port" | grep -qE '^[0-9]+$'; then
                echo -e "\e[1;31m输入无效：请输入一个数值。\e[0m"
            elif echo "$ports" | grep -q "^$port\$"; then
                ports=$(echo "$ports" | grep -v "^$port\$")
                echo -e "\e[1;32mPort $port removed.\e[0m"
            else
                ports=$(echo "$ports"; echo "$port" | grep -o '[0-9]\+')
                echo -e "\e[1;32mPort $port added.\e[0m"
            fi
        done

        if [ "$port" != "exit" ]; then
            new_ports_line="PORTS=($(echo "$ports" | tr '\n' ' '))"
            sed -i "s/$current_ports_line/$new_ports_line/" "$SIMPLE_FIREWALL_SCRIPT"
        fi
        ;;
    2)
        # TTL configuration code
        ttl_value=$(cat /usrdata/simplefirewall/ttlvalue)
        if [ "$ttl_value" -eq 0 ]; then
            echo -e "\e[1;31mTTL未设置\e[0m"
        else
            echo -e "\e[1;32mTTL已设置为$ttl_value.\e[0m"
        fi

        echo -e "\e[1;31m输入'exit'来取消。\e[0m"
        read -p "您希望TTL值是什么：" new_ttl_value
        if [ "$new_ttl_value" = "exit" ]; then
            echo -e "\e[1;31m正在退出TTL配置...\e[0m"
            return
        elif ! echo "$new_ttl_value" | grep -qE '^[0-9]+$'; then
            echo -e "\e[1;31m输入无效：请输入一个数值。\e[0m"
            return
        else
            /usrdata/simplefirewall/ttl-override stop
	    echo "$new_ttl_value" > /usrdata/simplefirewall/ttlvalue
     	    /usrdata/simplefirewall/ttl-override start
            echo -e "\033[0;32mTTL被更新为$new_ttl_value.\033[0m"
        fi
        ;;
    *)
        echo -e "\e[1;31m无效选择，请选择 1 或 2.\e[0m"
        ;;
    esac

    systemctl restart simplefirewall
    echo -e "\e[1;32m防火墙配置已更新。\e[0m"
}

set_simpleadmin_passwd(){
	ensure_entware_installed
 	opkg update
  	opkg install libaprutil
	wget -O /usrdata/root/bin/htpasswd https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleadmin/htpasswd && chmod +x /usrdata/root/bin/htpasswd
	wget -O /usrdata/root/bin/simplepasswd https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleadmin/simplepasswd && chmod +x /usrdata/root/bin/simplepasswd
	echo -e "\e[1;32m将来您需要使用web控制台（admin）密码访问...\e[0m"
	echo -e "\e[1;32m在控制台中键入web控制台的密码，然后按enter键\e[0m"
	/usrdata/root/bin/simplepasswd
	
}

set_root_passwd() {
	echo -e "\e[1;31m请设置root/console密码。\e[0m"
	/opt/bin/passwd
}

# Function to install/update Simple Admin
install_simple_admin() {
    while true; do
	echo -e "\e[1;32m将要安装新版web控制台，将在 80/443 端口开启服务\e[0m"
#echo -e "\e[1;32m111) Stable current version, (Main Branch)\e[0m"
	echo -e "\e[1;31m1) 安装\e[0m"
	echo -e "\e[0;33m0) 返回主菜单\e[0m"
 	echo -e "\e[1;32m选择您的操作: \e[0m"
        read choice

        case $choice in
        111)
            echo -e "\e[1;32mYou are using the development toolkit; Use the one from main if you want the stable version right 否w\e[0m"
            break
			;;
        1)
			ensure_entware_installed
			echo -e "\e[1;31m2) 开始安装新版控制台\e[0m"
			mkdir /usrdata/simpleupdates > /dev/null 2>&1
		    mkdir /usrdata/simpleupdates/scripts > /dev/null 2>&1
		    wget -O /usrdata/simpleupdates/scripts/update_socat-at-bridge.sh https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleupdates/scripts/update_socat-at-bridge.sh && chmod +x /usrdata/simpleupdates/scripts/update_socat-at-bridge.sh
		    echo -e "\e[1;32m安装/更新 依赖软件: socat-at-bridge\e[0m"
			echo -e "\e[1;32m请等待....\e[0m"
			/usrdata/simpleupdates/scripts/update_socat-at-bridge.sh
			echo -e "\e[1;32m 依赖包: socat-at-bridge 已被更新/安装完成.\e[0m"
			sleep 1
		    wget -O /usrdata/simpleupdates/scripts/update_simplefirewall.sh https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleupdates/scripts/update_simplefirewall.sh && chmod +x /usrdata/simpleupdates/scripts/update_simplefirewall.sh
		    echo -e "\e[1;32m安装/更新 依赖软件: simplefirewall\e[0m"
			echo -e "\e[1;32m请等待....\e[0m"
			/usrdata/simpleupdates/scripts/update_simplefirewall.sh
			echo -e "\e[1;32m 依赖包: simplefirewall 已被更新/安装完成.\e[0m"
			sleep 1
			set_simpleadmin_passwd
		    wget -O /usrdata/simpleupdates/scripts/update_simpleadmin.sh https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleupdates/scripts/update_simpleadmin.sh && chmod +x /usrdata/simpleupdates/scripts/update_simpleadmin.sh
			echo -e "\e[1;32m安装/更新: web控制台 组件\e[0m"
			echo -e "\e[1;32m请等待....\e[0m"
			/usrdata/simpleupdates/scripts/update_simpleadmin.sh
            echo -e "\e[1;32mweb控制台 组件已安装\e[0m"
			sleep 1
            break
            ;;
	    0)
                echo "返回主菜单..."
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
    done
}

# Function to Uninstall Simpleadmin and dependencies
uninstall_simpleadmin_components() {
    echo -e "\e[1;32m开始卸载web控制台.\e[0m"
    echo -e "\e[1;32m注意：卸载某些组件可能会影响其他组件的功能。\e[0m"
    remount_rw

    # Uninstall Simple Firewall
    echo -e "\e[1;32m是否卸载Simplefirewall?\e[0m"
#echo -e "\e[1;31mIf you do, the TTL part of simpleadmin will 否 longer work.\e[0m"
    echo -e "\e[1;32m1) 是\e[0m"
    echo -e "\e[1;31m2) 否\e[0m"
    read -p "请选择您要进行的操作(1 or 2): " choice_simplefirewall
    if [ "$choice_simplefirewall" -eq 1 ]; then
        echo "正在卸载Simplefirewall..."
        systemctl stop simplefirewall
        systemctl stop ttl-override
        rm -f /lib/systemd/system/simplefirewall.service
        rm -f /lib/systemd/system/ttl-override.service
        systemctl daemon-reload
        rm -rf "$SIMPLE_FIREWALL_DIR"
        echo "Simplefirewall卸载完成。"
    fi

    # Uninstall socat-at-bridge
    echo -e "\e[1;32m是否卸载socat-at-bridge?\e[0m"
#echo -e "\e[1;31mIf you do, AT commands and the stat page will 否 longer work. atcmd won't either.\e[0m"
    echo -e "\e[1;32m1) 是\e[0m"
    echo -e "\e[1;31m2) 否\e[0m"
    read -p "请选择您要进行的操作(1 or 2): " choice_socat_at_bridge
    if [ "$choice_socat_at_bridge" -eq 1 ]; then
        echo -e "\033[0;32mRemoving installed AT Socat Bridge services...\033[0m"
		systemctl stop at-telnet-daemon > /dev/null 2>&1
		systemctl disable at-telnet-daemon > /dev/null 2>&1
		systemctl stop socat-smd11 > /dev/null 2>&1
		systemctl stop socat-smd11-to-ttyIN > /dev/null 2>&1
		systemctl stop socat-smd11-from-ttyIN > /dev/null 2>&1
		systemctl stop socat-smd7 > /dev/null 2>&1
		systemctl stop socat-smd7-to-ttyIN2 > /dev/null 2>&1
		systemctl stop socat-smd7-to-ttyIN > /dev/null 2>&1
		systemctl stop socat-smd7-from-ttyIN2 > /dev/null 2>&1
		systemctl stop socat-smd7-from-ttyIN > /dev/null 2>&1
		rm /lib/systemd/system/at-telnet-daemon.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd11.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd11-to-ttyIN.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd11-from-ttyIN.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd7.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd7-to-ttyIN2.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd7-to-ttyIN.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd7-from-ttyIN.service > /dev/null 2>&1
		rm /lib/systemd/system/socat-smd7-from-ttyIN2.service > /dev/null 2>&1
		systemctl daemon-reload > /dev/null 2>&1
		rm -rf "$SOCAT_AT_DIR" > /dev/null 2>&1
		rm -rf "$SOCAT_AT_DIR" > /dev/null 2>&1
		rm -rf "/usrdata/micropython" > /dev/null 2>&1
		rm -rf "/usrdata/at-telnet" > /dev/null 2>&1
		echo -e "\033[0;32mAT Socat Bridge services removed!...\033[0m"
    fi

	# Uninstall ttyd
    echo -e "\e[1;32m是否卸载 ttyd (simpleadmin console)?\e[0m"
#echo -e "\e[1;31mWarning: Do 否t uninstall if you are currently using ttyd to do this!!!\e[0m"
    echo -e "\e[1;32m1) 是\e[0m"
    echo -e "\e[1;31m2) 否\e[0m"
    read -p "请选择您要进行的操作(1 or 2): " choice_simpleadmin
    if [ "$choice_simpleadmin" -eq 1 ]; then
		echo -e "\e[1;34mUninstalling ttyd...\e[0m"
        systemctl stop ttyd
        rm -rf /usrdata/ttyd
        rm /lib/systemd/system/ttyd.service
        rm /lib/systemd/system/multi-user.target.wants/ttyd.service
        rm /bin/ttyd
        echo -e "\e[1;32mttyd已被卸载\e[0m"
	fi

	echo "卸载web控制台剩余部分..."
		
	# Check if Lighttpd service is installed and remove it if present
	if [ -f "/lib/systemd/system/lighttpd.service" ]; then
		echo "检测到Lighttpd，正在卸载Lighttpd及其模块..."
		systemctl stop lighttpd
		opkg --force-remove --force-removal-of-dependent-packages remove lighttpd-mod-authn_file lighttpd-mod-auth lighttpd-mod-cgi lighttpd-mod-openssl lighttpd-mod-proxy lighttpd
		rm -rf $LIGHTTPD_DIR
	fi

	systemctl stop simpleadmin_generate_status
	systemctl stop simpleadmin_httpd
	rm -f /lib/systemd/system/simpleadmin_httpd.service
	rm -f /lib/systemd/system/simpleadmin_generate_status.service
	systemctl daemon-reload
	rm -rf "$SIMPLE_ADMIN_DIR"
	echo "web控制台剩余部分与 Lighttpd (if present) 卸载完成"
	remount_ro

    echo "卸载进程完成."
}

# Function for Tailscale Submenu
tailscale_menu() {
    while true; do
        echo -e "\e[1;32mTailscale Menu\e[0m"
	echo -e "\e[1;32m1) Install/Update Tailscale\e[0m"
	echo -e "\e[1;36m2) Configure Tailscale\e[0m"
	echo -e "\e[1;31m3) Return to Main Menu\e[0m"
        read -p "请选择您要进行的操作" tailscale_choice

        case $tailscale_choice in
            1) install_update_tailscale;;
            2) configure_tailscale;;
            3) break;;
            *) echo "Invalid option";;
        esac
    done
}

# Function to install, update, or remove Tailscale
install_update_tailscale() {
echo -e "\e[1;31m2) Installing tailscale from the $GITTREE branch\e[0m"
			ensure_entware_installed
			mkdir /usrdata/simpleupdates > /dev/null 2>&1
		    mkdir /usrdata/simpleupdates/scripts > /dev/null 2>&1
		    wget -O /usrdata/simpleupdates/scripts/update_tailscale.sh https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleupdates/scripts/update_tailscale.sh && chmod +x /usrdata/simpleupdates/scripts/update_tailscale.sh
		    echo -e "\e[1;32mInstalling/updating: Tailscale\e[0m"
			echo -e "\e[1;32mPlease Wait....\e[0m"
			remount_rw
   			/usrdata/simpleupdates/scripts/update_tailscale.sh
			echo -e "\e[1;32m Tailscale has been updated/installed.\e[0m"
}

# Function to Configure Tailscale
configure_tailscale() {
    while true; do
    echo "Configure Tailscale"
    echo -e "\e[38;5;40m1) Enable Tailscale Web UI at http://192.168.225.1:8088 (Gateway on port 8088)\e[0m"  # Green
    echo -e "\e[38;5;196m2) Disable Tailscale Web UI\e[0m"  # Red
    echo -e "\e[38;5;27m3) Connect to Tailnet\e[0m"  # Brown
    echo -e "\e[38;5;87m4) Connect to Tailnet with SSH ON\e[0m"  # Light cyan
    echo -e "\e[38;5;105m5) Reconnect to Tailnet with SSH OFF\e[0m"  # Light magenta
    echo -e "\e[38;5;172m6) Disconnect from Tailnet (reconnects at reboot)\e[0m"  # Light yellow
    echo -e "\e[1;31m7) Logout from tailscale account\e[0m"
    echo -e "\e[38;5;27m8) Return to Tailscale Menu\e[0m"
    read -p "请选择您要进行的操作" config_choice

        case $config_choice in
        1)
	remount_rw
	cd /lib/systemd/system/
	wget -O tailscale-webui.service https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/main/tailscale/systemd/tailscale-webui.service
  	wget -O tailscale-webui-trigger.service https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/main/tailscale/systemd/tailscale-webui-trigger.service
     	ln -sf /lib/systemd/system/tailscale-webui-trigger.service /lib/systemd/system/multi-user.target.wants/
     	systemctl daemon-reload
       	echo "Tailscale Web UI Enabled"
	echo "Starting Web UI..." 
     	systemctl start tailscale-webui
       	echo "Web UI started!"
     	remount_ro
	;;
	2) 
	remount_rw
  	systemctl stop tailscale-webui
    	systemctl disable tailscale-webui-trigger
  	rm /lib/systemd/system/multi-user.target.wants/tailscale-webui.service
    	rm /lib/systemd/system/multi-user.target.wants/tailscale-webui-trigger.service
    	rm /lib/systemd/system/tailscale-webui.service
      	rm /lib/systemd/system/tailscale-webui-trigger.service
     	systemctl daemon-reload
       	echo "Tailscale Web UI Stopped and Disabled"
     	remount_ro
	;;
	3) $TAILSCALE_DIR/tailscale up --accept-dns=false --reset;;
    4) $TAILSCALE_DIR/tailscale up --ssh --accept-dns=false --reset;;
	5) $TAILSCALE_DIR/tailscale up --accept-dns=false --reset;;
     	6) $TAILSCALE_DIR/tailscale down;;
        7) $TAILSCALE_DIR/tailscale logout;;
        8) break;;
        *) echo "Invalid option";;
        esac
    done
}

# Function to manage Daily Reboot Timer
manage_reboot_timer() {
    # Remount root filesystem as read-write
    mount -o remount,rw /

    # Check if the rebootmodem service, timer, or trigger already exists
    if [ -f /lib/systemd/system/rebootmodem.service ] || [ -f /lib/systemd/system/rebootmodem.timer ] || [ -f /lib/systemd/system/rebootmodem-trigger.service ]; then
        echo -e "\e[1;32mThe rebootmodem service/timer/trigger is already installed.\e[0m"
	echo -e "\e[1;32m1) Change\e[0m"  # Green
	echo -e "\e[1;31m2) Remove\e[0m"  # Red
        read -p "Enter your choice (1 for Change, 2 for Remove): " reboot_choice

        case $reboot_choice in
            2)
                # Stop and disable timer and trigger service by removing symlinks
                systemctl stop rebootmodem.timer
                systemctl stop rebootmodem-trigger.service

                # Remove symbolic links and files
                rm -f /lib/systemd/system/multi-user.target.wants/rebootmodem-trigger.service
                rm -f /lib/systemd/system/rebootmodem.service
                rm -f /lib/systemd/system/rebootmodem.timer
                rm -f /lib/systemd/system/rebootmodem-trigger.service
                rm -f "$USRDATA_DIR/reboot_modem.sh"

                # Reload systemd to apply changes
                systemctl daemon-reload

                echo -e "\e[1;32mRebootmodem service, timer, trigger, and script removed successfully.\e[0m"
                ;;
            1)
                printf "Enter the new time for daily reboot (24-hour format in Coordinated Universal Time, HH:MM): "
                read new_time

                # Validate the new time format using grep
                if ! echo "$new_time" | grep -qE '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'; then
                    echo "Invalid time format. Exiting."
                    exit 1
                else
                    # Remove old symlinks and script
                    rm -f /lib/systemd/system/multi-user.target.wants/rebootmodem-trigger.service
                    rm -f "$USRDATA_DIR/reboot_modem.sh"

                    # Set the user time to the new time and recreate the service, timer, trigger, and script
                    user_time=$new_time
                    create_service_and_timer
                fi
                ;;
            *)
                echo -e "\e[1;31mInvalid choice. Exiting.\e[0m"
                exit 1
                ;;
        esac
    else
        printf "Enter the time for daily reboot (24-hour format in UTC, HH:MM): "
        read user_time

        # Validate the time format using grep
        if ! echo "$user_time" | grep -qE '^([01]?[0-9]|2[0-3]):[0-5][0-9]$'; then
            echo "Invalid time format. Exiting."
            exit 1
        else
            create_service_and_timer
        fi
    fi

    # Remount root filesystem as read-only
    mount -o remount,ro /
}

# Function to create systemd service and timer files with the user-specified time for the reboot timer
create_service_and_timer() {
    remount_rw
    # Define the path for the modem reboot script
    MODEM_REBOOT_SCRIPT="$USRDATA_DIR/reboot_modem.sh"

    # Create the modem reboot script
    echo "#!/bin/sh
/bin/echo -e 'AT+CFUN=1,1 \r' > /dev/smd7" > "$MODEM_REBOOT_SCRIPT"

    # Make the script executable
    chmod +x "$MODEM_REBOOT_SCRIPT"

    # Create the systemd service file for reboot
    echo "[Unit]
Description=Reboot Modem Daily

[Service]
Type=oneshot
ExecStart=/bin/sh /usrdata/reboot_modem.sh
Restart=否
RemainAfterExit=否" > /lib/systemd/system/rebootmodem.service

    # Create the systemd timer file with the user-specified time
    echo "[Unit]
Description=Starts rebootmodem.service daily at the specified time

[Timer]
OnCalendar=*-*-* $user_time:00
Persistent=false" > /lib/systemd/system/rebootmodem.timer

    # Create a trigger service that starts the timer at boot
    echo "[Unit]
Description=Trigger the rebootmodem timer at boot

[Service]
Type=oneshot
ExecStart=/bin/systemctl start rebootmodem.timer
RemainAfterExit=是" > /lib/systemd/system/rebootmodem-trigger.service

    # Create symbolic links for the trigger service in the wanted directory
    ln -sf /lib/systemd/system/rebootmodem-trigger.service /lib/systemd/system/multi-user.target.wants/

    # Reload systemd to recognize the new timer and trigger service
    systemctl daemon-reload
    sleep 2s

    # Start the trigger service, which will start the timer
    systemctl start rebootmodem-trigger.service
    remount_ro

    # Confirmation
    echo -e "\e[1;32mRebootmodem-trigger service created and started successfully.\e[0m"
    echo -e "\e[1;32mReboot schedule set successfully. The modem will reboot daily at $user_time UTC.\e[0m"
}

manage_cfun_fix() {
    cfun_service_path="/lib/systemd/system/cfunfix.service"
    cfun_fix_script="/usrdata/cfun_fix.sh"

    mount -o remount,rw /

    if [ -f "$cfun_service_path" ]; then
        echo -e "\e[1;32mThe CFUN fix is already installed. Do you want to remove it?\e[0m"  # Green
	echo -e "\e[1;32m1) 是\e[0m"  # Green
	echo -e "\e[1;31m2) 否\e[0m"   # Red
        read -p "请选择您要进行的操作" choice

        if [ "$choice" = "1" ]; then
            echo "Removing CFUN fix..."
            systemctl stop cfunfix.service
            rm -f /lib/systemd/system/multi-user.target.wants/cfunfix.service
            rm -f "$cfun_service_path"
            rm -f "$cfun_fix_script"
            systemctl daemon-reload
            echo "CFUN fix has been removed."
        else
            echo "Returning to main menu..."
        fi
    else
        echo -e "\e[1;32mInstalling CFUN fix...\e[0m"

        # Create the CFUN fix script
        echo "#!/bin/sh
/bin/echo -e 'AT+CFUN=1 \r' > /dev/smd7" > "$cfun_fix_script"
        chmod +x "$cfun_fix_script"

        # Create the systemd service file to execute the CFUN fix script at boot
        echo "[Unit]
Description=CFUN Fix Service
After=network.target

[Service]
Type=oneshot
ExecStart=$cfun_fix_script
RemainAfterExit=是

[Install]
WantedBy=multi-user.target" > "$cfun_service_path"

        ln -sf "$cfun_service_path" "/lib/systemd/system/multi-user.target.wants/"
	systemctl daemon-reload
 	mount -o remount,ro /
        echo -e "\e[1;32mCFUN fix has been installed and will execute at every boot.\e[0m"
    fi
}


install_sshd() {
    if [ -d "/usrdata/sshd" ]; then
        echo -e "\e[1;31mSSHD is currently installed.\e[0m"
        echo -e "Do you want to update or uninstall?"
        echo -e "1.) Update"
        echo -e "2.) Uninstall"
        read -p "Select an option (1 or 2): " sshd_choice

        case $sshd_choice in
            1)
				echo -e "\e[1;31m2) Installing sshd from the $GITTREE branch\e[0m"
                ;;
            2)
                echo -e "\e[1;31mUninstalling SSHD...\e[0m"
                systemctl stop sshd
                rm /lib/systemd/system/sshd.service
                opkg remove openssh-server-pam
                echo -e "\e[1;32mSSHD has been uninstalled successfully.\e[0m"
                return 0
                ;;
            *)
                echo -e "\e[1;31mInvalid option. Please select 1 or 2.\e[0m"
                return 1
                ;;
        esac
    fi

    # Proceed with installation or updating if 否t uninstalling
	ensure_entware_installed
    mkdir /usrdata/simpleupdates > /dev/null 2>&1
	mkdir /usrdata/simpleupdates/scripts > /dev/null 2>&1
	wget -O /usrdata/simpleupdates/scripts/update_sshd.sh https://raw.githubusercontentS.com/$GITUSER/quectel-rgmii-toolkit/$GITTREE/simpleupdates/scripts/update_sshd.sh && chmod +x /usrdata/simpleupdates/scripts/update_sshd.sh
	echo -e "\e[1;32mInstalling/updating: SSHd\e[0m"
	echo -e "\e[1;32mPlease Wait....\e[0m"
	/usrdata/simpleupdates/scripts/update_sshd.sh
	echo -e "\e[1;32m SSHd has been updated/installed.\e[0m"
}


# Main menu
while true; do

    echo -e "\e[92m"
    echo "欢迎使用卤蛋瞎鼓捣出来的移远模块web控制台安装程序"
    echo "感谢@Sy对本web控制台进行汉化"
    echo -e "\e[0m"
    echo "选择一个操作:"
    echo -e "\e[0m"
    echo -e "\e[93m1) 安装web控制台\e[0m" # Yellow
	echo -e "\e[95m2) 设置web控制台 (admin) 密码\e[0m" # Light Purple
	echo -e "\e[94m3) 设置Console/ttyd (root) 密码\e[0m" # Light Blue
    echo -e "\e[96m4) 发送AT指令\e[0m" # Cyan
    echo -e "\e[91m5) 卸载web控制台\e[0m" # Light Red	
#echo -e "\e[95m6) Simple Firewall Management\e[0m" # Light Purple
#echo -e "\e[94m7) Tailscale Management\e[0m" # Light Blue
#echo -e "\e[92m8) Install/Change or remove Daily Reboot Timer\e[0m" # Light Green
#echo -e "\e[96m9) Install/Uninstall CFUN 0 Fix\e[0m" # Cyan (repeated color for additional options)
#echo -e "\e[91m10) Uninstall Entware/OPKG\e[0m" # Light Red
#echo -e "\e[92m11) Install Speedtest.net CLI app (speedtest command)\e[0m" # Light Green
#echo -e "\e[92m12) Install Fast.com CLI app (fast command)(tops out at 40Mbps)\e[0m" # Light Green
#echo -e "\e[92m13) Install OpenSSH Server\e[0m" # Light Green
    echo -e "\e[93m0) 退出\e[0m" # Yellow (repeated color for exit option)
    read -p "请选择您要进行的操作" choice

    case $choice in
        4)
            send_at_commands
            ;;
        1)
            install_simple_admin
            ;;
		2)	set_simpleadmin_passwd
			;;
		3)
			set_root_passwd
			;;
		5)
			uninstall_simpleadmin_components
			;;
		116)
			configure_simple_firewall
            ;;
        
        117)  
			tailscale_menu
	        ;;
		118)
			manage_reboot_timer
            ;;
		119)
			manage_cfun_fix
            ;;	    
		110)
			echo -e "\033[31mAre you sure you want to uninstall entware?\033[0m"
			echo -e "\033[31m1) 是\033[0m"
			echo -e "\033[31m2) 否\033[0m"
			read -p "Select an option (1 or 2): " user_choice

			case $user_choice in
				1)
					# If 是, uninstall existing entware
					echo -e "\033[31mUninstalling existing entware...\033[0m"
					uninstall_entware  # Assuming uninstall_entware is a defined function or command
					echo -e "\033[31mEntware has been uninstalled.\033[0m"
					;;
				2)
					# If 否, exit the script
					echo -e "\033[31mUninstallation cancelled.\033[0m"
					exit  # Use 'exit' to terminate the script outside a loop
					;;
				*)
					# Handle invalid input
					echo -e "\033[31mInvalid option. Please select 1 or 2.\033[0m"
					;;
			esac
			;;

		111) 
			ensure_entware_installed
			echo -e "\e[1;32mInstalling Speedtest.net CLI (speedtest command)\e[0m"
     	    remount_rw
			mkdir /usrdata/root
     	    mkdir /usrdata/root/bin
			cd /usrdata/root/bin
     	    wget https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armhf.tgz
			tar -xzf ookla-speedtest-1.2.0-linux-armhf.tgz
     	    rm ookla-speedtest-1.2.0-linux-armhf.tgz
			rm speedtest.md
     	    cd /
			ln -sf /usrdata/root/bin/speedtest /bin
     	    remount_ro
			echo -e "\e[1;32mSpeedtest CLI (speedtest command) installed!!\e[0m"
     	    echo -e "\e[1;32mTry running the command 'speedtest'\e[0m"
			echo -e "\e[1;32m否te that it will 否t work unless you login to the root account first\e[0m"
			echo -e "\e[1;32m否rmaly only an issue in adb, ttyd and ssh you are forced to login\e[0m"
			echo -e "\e[1;32mIf in adb just type login and then try to run the speedtest command\e[0m"
            ;;

		113) 
			install_sshd
			;;
		0) 
			echo -e "\e[1;32mG拜拜了您内!\e[0m"
     	    break
            ;;    
    *)
			echo -e "\e[1;31m无效选项\e[0m"
            ;;
    esac
done
