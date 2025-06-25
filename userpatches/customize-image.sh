#!/bin/bash

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	echo "======================== arch: $BOARD ===================================="

	systemctl disable systemd-resolved
	systemctl mask systemd-resolved

	rm -f /etc/apt/sources.list
    cat <<EOF > /etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
	apt update -y
	apt install -y ppp tcpdump bpftool iptables zip unzip hostapd iw dnsutils

	# docker instell start
	sudo apt-get install ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update

	apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	cat <<EOF > /etc/docker/daemon.json
{
	"bip": "172.18.1.1/24",
	"dns": ["172.18.1.1"]
}
EOF
	systemctl start docker

	if [ "$BOARD" = "uefi-x86" ]; then
		# 当 BOARD 为 "uefi-x86" 时执行的操作
		if [ -f "/tmp/overlay/landscape-webserver-x86_64" ]; then
			echo "文件已存在，直接复制..."
			cp /tmp/overlay/landscape-webserver-x86_64 /root/landscape-webserver
		else
			# 文件不存在，进行下载
			echo "下载 landscape-webserver..."
			curl -L -o /root/landscape-webserver https://github.com/ThisSeanZhang/landscape/releases/latest/download/landscape-webserver-x86_64
		fi
		sudo sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 /' /etc/default/grub
		sudo update-grub
	else
		if [ -f "/tmp/overlay/landscape-webserver-aarch64" ]; then
			echo "文件已存在，直接复制..."
			cp /tmp/overlay/landscape-webserver-aarch64 /root/landscape-webserver
		else
			# 文件不存在，进行下载
			echo "下载 landscape-webserver..."
			curl -L -o /root/landscape-webserver https://github.com/ThisSeanZhang/landscape/releases/latest/download/landscape-webserver-aarch64
		fi
		# 当 BOARD 为其他值时执行的操作
		cat /boot/armbianEnv.txt
		# 使用默认的方式进行命名
		echo "extraargs=net.ifnames=0 biosdevname=0" | sudo tee -a /boot/armbianEnv.txt
	fi

	mkdir -p /root/.landscape-router/
	cp "/tmp/overlay/landscape_init-${BOARD}.toml" "/root/.landscape-router/landscape_init.toml"
	chmod +x /root/landscape-webserver
	if [ -f "/tmp/overlay/static.zip" ]; then
		echo "static.zip 文件已存在，直接复制..."
		cp /tmp/overlay/static.zip /root/static.zip
	else
		# 文件不存在，进行下载
		echo "下载 static.zip..."
		curl -L -o /root/static.zip https://github.com/ThisSeanZhang/landscape/releases/latest/download/static.zip
	fi
	unzip /root/static.zip -d /root/.landscape-router
	cat <<EOF > /etc/systemd/system/landscape-router.service
[Unit]
Description=Landscape Router
After=docker.service
Requires=docker.service

[Service]
ExecStart=/root/landscape-webserver
Restart=always
User=root
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
	systemctl enable landscape-router.service

	cat <<EOF > /root/.not_logged_in_yet
# /root/.not_logged_in_yet
# 自动配置 Armbian 首次启动设置
#
# 设置根用户密码（注意：密码以明文存储，建议使用 SSH 密钥替代密码）
PRESET_ROOT_PASSWORD="123456"

# 设置系统语言和区域
PRESET_LOCALE="en_US.UTF-8"

# 设置系统时区
PRESET_TIMEZONE="Asia/Shanghai"

PRESET_NET_CHANGE_DEFAULTS="0"
PRESET_NET_ETHERNET_ENABLED="0"
PRESET_NET_WIFI_ENABLED="0"
PRESET_CONNECT_WIRELESS="n"
PRESET_NET_USE_STATIC="0"
SET_LANG_BASED_ON_LOCATION="n"


# PRESET_USER_NAME="sean"
# PRESET_DEFAULT_REALNAME="Sean"
# PRESET_USER_PASSWORD="123456"
# PRESET_USER_SHELL="bash"
EOF
} # Main


Main "$@"
