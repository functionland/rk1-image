#!/bin/sh

#rk1-image root dir
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_PATH=$DIR/build
ARMBIAN_PATH=$BUILD_PATH/armbian-build
ARMBIAN_IMAGE_PATH=$ARMBIAN_PATH/output/images
OUTPUT_PATH=$DIR/output
########################################################
Main() {

	# read all variable from config file
	source $DIR/config

	mkdir -p $BUILD_PATH

	#download armbian src
	#ArmbianSrcInit;

	#compile armbian
	#ArmbianCompileServer;

	CreateUsbFlashUpdate;

} # Main
########################################################
ArmbianSrcInit()
{
	echo "install armbian required package"
	# if docker dosn't exist install it
	if ! command -v docker &> /dev/null
	then
		echo "installing docker"
		curl -fsSL https://get.docker.com -o $BUILD_PATH/get-docker.sh
		sudo sh $BUILD_PATH/get-docker.sh
	fi

	sudo apt-get -y -qq install git

	#get armbian-biuld
	if [ -d $ARMBIAN_PATH ]; then
		echo "update armbian-build branch $ARMBIAN_REPO_BRANCH"
		git -C $ARMBIAN_PATH pull
	else
		echo "clone armbian-build branch $ARMBIAN_REPO_BRANCH"
		git clone --depth=1 --branch=$ARMBIAN_BRANCH https://github.com/armbian/build $ARMBIAN_PATH
	fi
	
	#get armbian userpatches
	if [ -d $ARMBIAN_PATH/userpatches ]; then
		echo "update armbian userpatches repo"
		git -C $ARMBIAN_PATH/userpatches pull
	else
		echo "clone armbian userpatches repo"
		git clone --depth=1  https://github.com/mahdichi/armbian_userpatches $ARMBIAN_PATH/userpatches/
	fi

} # ArmbianSrcInit
########################################################
ArmbianCompileServer()
{
#https://docs.armbian.com/Developer-Guide_Build-Options/

	$ARMBIAN_PATH/compile.sh \
	BOARD=fxblox-rk1 \
	BRANCH=legacy \
	RELEASE=jammy \
	BUILD_DESKTOP=no \
	BUILD_MINIMAL=yes \
	KERNEL_CONFIGURE=no \
	KERNEL_GIT=shallow \
	CONSOLE_AUTOLOGIN=yes \
	EXPERT="yes" \
	CLEAN_LEVEL=oldcache \
	PACKAGE_LIST_BOARD="\
	cmake libi2c-dev \
	gdb git gcc net-tools rfkill bluetooth bluez bluez-tools blueman \
	logrotate python3-pip mergerfs inotify-tools python3-dbus dnsmasq-base \
	python3-dev python-is-python3 python3-pip python3-gi python3-gi-cairo gir1.2-gtk-3.0 dnsmasq-base lshw  \
	debhelper build-essential ntfs-3g fakeroot lockfile-progs \
	libip6tc2 libnftnl11 iptables \
	" \
	#usbmount: ebhelper build-essential ntfs-3g fakeroot lockfile-progs
	#docker:   libip6tc2 libnftnl11 iptables
	#fula: logrotate

} # ArmbianCompileServer
########################################################
ArmbianCompileDesktop()
{
	$ARMBIAN_PATH/compile.sh \
	BOARD=fxblox-rk1 \
	BRANCH=legacy \
	BUILD_DESKTOP=yes \
	BUILD_MINIMAL=no \
	DESKTOP_APPGROUPS_SELECTED='3dsupport browsers chat desktop_tools editors email internet multimedia office remote_desktop' \
	DESKTOP_ENVIRONMENT=gnome \
	DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
	KERNEL_CONFIGURE=no \
	RELEASE=jammy \
	KERNEL_GIT=shallow \
	EXPERT="yes" \
	CLEAN_LEVEL=oldcache \
	\
	PACKAGE_LIST_BOARD="\
	cmake libi2c-dev \
	gdb git gcc net-tools rfkill bluetooth bluez bluez-tools blueman \
	logrotate python3-pip mergerfs inotify-tools python3-dbus dnsmasq-base \
	python3-dev python-is-python3 python3-pip python3-gi python3-gi-cairo gir1.2-gtk-3.0 dnsmasq-base lshw  \
	debhelper build-essential ntfs-3g fakeroot lockfile-progs \
	libip6tc2 libnftnl11 iptables \
	" \
	#usbmount: ebhelper build-essential ntfs-3g fakeroot lockfile-progs
	#docker:   libip6tc2 libnftnl11 iptables
	#fula: logrotate

} # ArmbianCompileDesktop
########################################################
CreateUsbFlashUpdate()
{
	echo "Create USB Flash Update files"

	mkdir -p $OUTPUT_PATH

	#split -d -a 1 -b 1G $ARMBIAN_IMAGE_PATH/*.img $OUTPUT_PATH/update.img. --verbose

	fileCnt=$(ls -l "update.img.*" | wc -l)

	echo $fileCnt

	touch $OUTPUT_PATH/boot.cmd



} #CreateUsbFlashUpdate
########################################################
Main "$@"