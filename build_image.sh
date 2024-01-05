#!/bin/sh

#rk1-image root dir
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

BUILD_PATH=$DIR/build
ARMBIAN_PATH=$BUILD_PATH/armbian-build
ARMBIAN_IMAGE_PATH=$ARMBIAN_PATH/output/images
########################################################
Main() {

	# read all variable from config file
	source $DIR/config
	
	mkdir -p $BUILD_PATH

	#download armbian src
	ArmbianSrcInit;

	#compile armbian
	#ArmbianCompileServer;
	ArmbianCompileDesktop;

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
	rm -rf $ARMBIAN_PATH/userpatches/
	cp -r $DIR/userpatches/ $ARMBIAN_PATH/userpatches/

	# if [ -d $ARMBIAN_PATH/userpatches ]; then
	# 	echo "update armbian userpatches repo"
	# 	git -C $ARMBIAN_PATH/userpatches pull
	# else
	# 	echo "clone armbian userpatches repo"
	# 	git clone --depth=1  https://github.com/mahdichi/armbian_userpatches $ARMBIAN_PATH/userpatches/
	# fi

	#copy config to overlay for access in chroot
	cp $DIR/config $ARMBIAN_PATH/userpatches/overlay/

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
	
	echo "Split update file to 1GB parts"
	split -d -a 1 -b 1G $ARMBIAN_IMAGE_PATH/*.img $BUILD_PATH/update.img. --verbose

	echo "create boot script"
	fileCnt=$(ls -l $BUILD_PATH/update.img.* | wc -l)
	touch $BUILD_PATH/boot.cmd

	cat > $BUILD_PATH/boot.cmd <<- EOF
	echo "******************************************"
	echo "usb update starting"
	echo "******************************************"

	setenv load_addr "0x9000000"
	setenv load_size "0x40000000"

	setenv load_addr_part_0 "0x0000000"
	setenv load_addr_part_1 "0x0200000"
	setenv load_addr_part_2 "0x0400000"
	setenv load_addr_part_3 "0x0600000"
	setenv load_addr_part_4 "0x0800000"
	setenv load_addr_part_5 "0x0A00000"
	setenv load_addr_part_6 "0x0C00000"
	setenv load_addr_part_7 "0x0E00000"
	setenv load_addr_part_8 "0x1000000"
	setenv load_addr_part_9 "0x1200000"
	EOF



	cat >> $BUILD_PATH/boot.cmd <<- EOF


	mmc rescan
	mmc list
	mmc dev 0

	usb reset
	usb dev 0

	mmc list
	mmc dev

	if test -e usb 0:1 update.img.0 ; then
	    echo "******************************************"
	    echo "usb: there is update file"

	    #turn on red led
	    gpio clear gpio211

	    #turn off blue led
	    gpio set gpio212

	EOF

	#for (( i=0; i<$fileCnt; i++ ))
	#do
	i=0
	while [ "$i" -lt $fileCnt ]; do
		cat >> $BUILD_PATH/boot.cmd <<- EOF

	    size usb 0:1 update.img.$i
	    echo "usb: part $i image size: \${filesize} bytes"	
	    echo "usb: wait for copy part $i image to DDR"
	    fatload usb 0:1 \${load_addr} update.img.$i
	    echo "usb: part $i copy complete"	
	    setexpr file_size_blk \${filesize} / 0x200
	    echo "emmc: part $i image block size: \${file_size_blk}"	
	    echo "emmc: wait for copy part $i image to eMMC"
	    mmc write \${load_addr} \${load_addr_part_$i} \${file_size_blk}
	    echo "emmc: part $i copy completed"
		
		EOF
		i=$(( i + 1 ))
	done


	cat >> $BUILD_PATH/boot.cmd <<- EOF

	    rkimgtest mmc 0

	    echo " "
	    echo "please remove USB"
	    echo ""
	    echo "******************************************"

	    #turn off red led
	    gpio set gpio211

	    #turn on blue led
	    gpio clear gpio212	

	    while true ; do ; 
	    gpio set gpio212 && 
	    usb reset &&
	    gpio clear gpio212 && 
	    usb reset &&
	    ; done;

	fi

	EOF

	# boot script
	sudo apt-get -qq install u-boot-tools
	mkimage -C none -A arm -T script -d $BUILD_PATH/boot.cmd $BUILD_PATH/boot.scr

	# zip output 
	echo "zip all update file to $BUILD_PATH/update.zip"
	cd $BUILD_PATH
	zip -r update.zip update.img.* boot.scr

} #CreateUsbFlashUpdate
########################################################
Main "$@"
