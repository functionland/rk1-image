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

	CreatUser;

	InstallpythonPackages;

	InstallDocker;
	#InstallDockerOffline;

	InstallFulaOTA;

} # fxBloxCustomScript

CreatUser()
{
	echo "Creat User"

	rm /root/.not_logged_in_yet
	export LANG=C LC_ALL="en_US.UTF-8"

	# set root password
	password=$ARMBIAN_ROOT_PASSWORD
	(
		echo "$password"
		echo "$password"
	) | passwd root > /dev/null 2>&1


	# set shell
	USER_SHELL="bash"
	SHELL_PATH=$(grep "/$USER_SHELL$" /etc/shells | tail -1)
	chsh -s "$(grep -iF "/$USER_SHELL" /etc/shells | tail -1)"
	sed -i "s|^SHELL=.*|SHELL=${SHELL_PATH}|" /etc/default/useradd
	sed -i "s|^DSHELL=.*|DSHELL=${SHELL_PATH}|" /etc/adduser.conf

	# create user
	RealUserName=$ARMBIAN_USER_NAME
	RealName=$ARMBIAN_USER_NAME
	password=$ARMBIAN_USER_PASSWORD

	adduser --quiet --disabled-password --home /home/"$RealUserName" --gecos "$RealName" "$RealUserName"
	(
		echo "$password"
		echo "$password"
	) | passwd "$RealUserName" > /dev/null 2>&1

	mkdir -p /home/$ARMBIAN_USER_NAME/
	#chown -R "$RealUserName":"$RealUserName" /home/pi/

	for additionalgroup in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh; do
		usermod -aG "${additionalgroup}" "${RealUserName}" 2> /dev/null
	done

	# fix for gksu in Xenial
	touch /home/"$RealUserName"/.Xauthority
	chown "$RealUserName":"$RealUserName" /home/"$RealUserName"/.Xauthority
	RealName="$(awk -F":" "/^${RealUserName}:/ {print \$5}" < /etc/passwd | cut -d',' -f1)"
	[ -z "$RealName" ] && RealName="$RealUserName"
	#echo -e "\nDear \e[0;92m${RealName}\x1B[0m, your account \e[0;92m${RealUserName}\x1B[0m has been created and is sudo enabled."
	#echo -e "Please use this account for your daily work from now on.\n"
	rm -f /root/.not_logged_in_yet
	chmod +x /etc/update-motd.d/*
	# set up profile sync daemon on desktop systems
	if command -v psd > /dev/null 2>&1; then
		echo -e "${RealUserName} ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
		touch /home/"${RealUserName}"/.activate_psd
		chown "$RealUserName":"$RealUserName" /home/"${RealUserName}"/.activate_psd
	fi
} # CreatUser

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
	chown -R $ARMBIAN_USER_NAME:$ARMBIAN_USER_NAME /home/$ARMBIAN_USER_NAME

	git clone -b main https://github.com/functionland/fula-ota /home/$ARMBIAN_USER_NAME/fula-ota

	#copy offline docker
	#mkdir -p /usr/bin/fula/
	#cp /tmp/overlay/offline_docker/* /usr/bin/fula/

	cd /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux
	bash ./fula.sh install chroot

	#disable resize rootfs
	touch /usr/bin/fula/.resize_flg

	#automount
	cp /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/automount.sh /usr/local/bin/automount.sh
	chmod +x /usr/local/bin/automount.sh
	cp /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/99-automount.rules /etc/udev/rules.d/99-automount.rules
	cp /home/$ARMBIAN_USER_NAME/fula-ota/docker/fxsupport/linux/automount@.service /etc/systemd/system/automount@.service

	cd /tmp

} # InstallFulaOTA


Main "$@"
