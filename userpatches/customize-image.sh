#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	case $RELEASE in
		stretch)
			# your code here
			# InstallOpenMediaVault # uncomment to get an OMV 4 image
			;;
		buster)
			# your code here
			;;
		bullseye)
			# your code here
			;;
		bionic)
			# your code here
			;;
		focal)
			# your code here
			;;
		jammy)
			Install;
			;;
	esac
} # Main

Install()
{
	if [ "${BOARD}" = "fxblox-rk1" ]; then
		fxBloxCustomScript;
	fi
} # Install

fxBloxCustomScript()
{
	echo "fxBlox Custom Script"

	# read all variable from config file
	source /tmp/overlay/config
		
	#fix blutooth frimware loading error
	echo "fix blutooth"
	ln -s /lib/firmware/rtl8852bu_config /lib/firmware/rtl_bt/rtl8852bu_config.bin
	ln -s /lib/firmware/rtl8852bu_fw /lib/firmware/rtl_bt/rtl8852bu_fw.bin

 	# Increase UDP buffer size
	sysctl -w net.core.rmem_default=2097152
	sysctl -w net.core.rmem_max=2097152
	
	# Optionally, you might want to increase the send buffer size as well
	sysctl -w net.core.wmem_default=2097152
	sysctl -w net.core.wmem_max=2097152

	fxBloxCustomScriptService;

	InstallpythonPackages;
	
	InstallDocker;
	#InstallDockerOffline;
	
	InstallFulaOTA;

} # fxBloxCustomScript

fxBloxCustomScriptService()
{
	echo "install fxBlox Custom Script Service"

	rm /root/.not_logged_in_yet

	mkdir -p /usr/bin/fula/
	cp /tmp/overlay/config /usr/bin/fula/

	touch /root/.fxBlox_custom_script_service
	cp /tmp/overlay/fxBlox_custom_script_service.sh /usr/bin/fxBlox_custom_script_service.sh
	chmod +x /usr/bin/fxBlox_custom_script_service.sh

	touch /etc/systemd/system/fxBlox_custom_script_service.service

	cat > /etc/systemd/system/fxBlox_custom_script_service.service <<- EOF
	[Unit]
	Description=fxBlox_custom_script_service service
	After=multi-user.target

	[Service]
	ExecStart=/bin/bash /usr/bin/fxBlox_custom_script_service.sh
	Type=simple

	[Install]
	WantedBy=multi-user.target
	EOF
	systemctl --no-reload enable fxBlox_custom_script_service.service

} # fxBloxCustomScriptService

InstallpythonPackages()
{
	echo "Install python Packages"

	pip install RPi.GPIO
	pip install pexpect
	pip install psutil
} # InstallpythonPackages

InstallDocker()
{
	echo "installing docker"

	#Add Docker's official GPG key:
	for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt remove $pkg; done
	#apt-get update
	apt install ca-certificates curl gnupg
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	chmod a+r /etc/apt/keyrings/docker.gpg

	# Add the repository to Apt sources:
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	  tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt update

	apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	#Install Docker Compose 1.29.2
	echo "Docker Compose"
	curl -L "https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
} # InstallDocker

InstallDockerOffline()
{
	echo "installing docker"
	apt install /tmp/overlay/docker/*.deb

	#Install Docker Compose 1.29.2
	echo "Docker Compose"
	cp /tmp/overlay/docker/docker-compose /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

} # InstallDockerOffline

InstallFulaOTA()
{
	echo "Install Fula OTA"

	mkdir -p /home/$ARMBIAN_USER_NAME
	#chown -R $ARMBIAN_USER_NAME:$ARMBIAN_USER_NAME /home/$ARMBIAN_USER_NAME

	git clone -b main https://github.com/functionland/fula-ota /home/$ARMBIAN_USER_NAME/fula-ota

	#copy offline docker
	#mkdir -p /usr/bin/fula/
	#cp /tmp/overlay/offline_docker/* /usr/bin/fula/

	cd /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux
	bash /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/fula.sh install chroot

	#disable resize rootfs
	touch /usr/bin/fula/.resize_flg

 	#Mark installation as completed
	touch /home/$ARMBIAN_USER_NAME/V6.info

	#automount
	cp /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/automount.sh /usr/local/bin/automount.sh
	chmod +x /usr/local/bin/automount.sh
	cp /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/99-automount.rules /etc/udev/rules.d/99-automount.rules
	cp /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/automount@.service /etc/systemd/system/automount@.service

	cd /tmp

} # InstallFulaOTA


Main "$@"
