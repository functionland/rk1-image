#!/bin/sh

#rk1-image root dir
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

BUILD_PATH=$DIR/build
ARMBIAN_PATH=$BUILD_PATH/armbian-build
ARMBIAN_IMAGE_PATH=$ARMBIAN_PATH/output/images
BOOTLOADER_IMAGE_PATH=$ARMBIAN_PATH/cache/sources/u-boot-worktree/u-boot-rockchip64/next-dev-v2024.03/
########################################################
Main() {

	# read all variable from config file
	source $DIR/config
	
	# if [ -d $BUILD_PATH ]; then
	# 	rm -rf "$BUILD_PATH"
	# fi
	mkdir -p $BUILD_PATH

	#download armbian src
	ArmbianSrcInit;

	#compile armbian
	if [ -z "${1}" ]
	then
		echo "error No Image selected"
		exit 1;
	fi

	if [ $1 = "server" ]
	then
		echo "Compile Server Image"
		ArmbianCompileServer;
	elif [ $1 = "desktop" ]
	then
		echo "Compile Desktop Image"
		ArmbianCompileDesktop;
	else
		echo "error wrong Image selected"
	fi

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

	#get armbian-build
	# if [ -d $ARMBIAN_PATH ]; then
	# 	rm -rf "$ARMBIAN_PATH"
	# fi

	echo "clone armbian-build branch $ARMBIAN_REPO_BRANCH"
	git clone --depth=1 --branch=$ARMBIAN_BRANCH https://github.com/armbian/build $ARMBIAN_PATH
	
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
	BRANCH=vendor \
	RELEASE=jammy \
	EXTRAWIFI=yes \
	BUILD_DESKTOP=no \
	BUILD_MINIMAL=yes \
	KERNEL_CONFIGURE=no \
	KERNEL_GIT=shallow \
	CONSOLE_AUTOLOGIN=yes \
	EXPERT="yes" \
	CLEAN_LEVEL=oldcache \
 	NETWORKING_STACK=network-manager \
	PACKAGE_LIST_BOARD="\
	cmake libi2c-dev \
	gdb git gcc net-tools rfkill bluetooth bluez bluez-tools blueman \
	logrotate python3-pip mergerfs inotify-tools python3-dbus dnsmasq-base \
	python3-dev python-is-python3 python3-pip python3-gi python3-gi-cairo gir1.2-gtk-3.0 dnsmasq-base lshw  \
	debhelper build-essential ntfs-3g fakeroot lockfile-progs \
	libip6tc2 libnftnl11 iptables iptables-persistent dnsutils resolvconf \
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
	BRANCH=vendor \
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
	libip6tc2 libnftnl11 iptables iptables-persistent dnsutils resolvconf \
	" \
	#usbmount: ebhelper build-essential ntfs-3g fakeroot lockfile-progs
	#docker:   libip6tc2 libnftnl11 iptables
	#fula: logrotate

} # ArmbianCompileDesktop
########################################################
CreateUsbFlashUpdate()
{
	echo "Create USB Flash Update files"

	echo "copy bootloader to output folder"
	cp $BOOTLOADER_IMAGE_PATH/rkspi_loader.img $BUILD_PATH/flash.img
	
	echo "Split update file to 1GB parts"
	split -d -a 1 -b 1G $ARMBIAN_IMAGE_PATH/*.img $BUILD_PATH/update.img. --verbose

	echo "create boot script"
	fileCnt=$(ls -l $BUILD_PATH/update.img.* | wc -l)
	touch $BUILD_PATH/boot.cmd

	cat > $BUILD_PATH/boot.cmd <<- EOF
	echo "******************************************"
	echo "usb update starting"
	echo "******************************************"

	setenv load_addr0 "0x09000000"
	setenv load_addr1 "0x0B000000"
	setenv load_size  "0x40000000"

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

	mtd_blk dev 2

	mmc list
	mmc dev

	fatload usb 0:1 \${load_addr0} flash.img
	echo "usb: flash image size: \${filesize} bytes"
	
	setexpr file_size_blk \${filesize} / 0x200
	echo "mtd: flash image block size: \${file_size_blk}"	

	mtd_blk read \${load_addr1} 0 \${file_size_blk}

	setexpr cmp_size \${filesize} / 4 
	echo "cmp: cmp size: \${cmp_size}"

	echo "cmp: compare usb flash.img with mtd content"	
	cmp \${load_addr0} \${load_addr1} \${cmp_size}

	if test \$? -eq 0 ; then
		echo "******************************************"
		echo "usb: flash already updated"
		echo "******************************************"
	else
		if test -e usb 0:1 flash.img ; then
			echo "******************************************"
			echo "usb: there is flash update file"

			#turn on red led
			gpio clear gpio211

			#turn off blue led
			gpio set gpio212

			echo "mtd: wait for copy flash image to Nor Flash"
			mtd_blk write \${load_addr0} 0 \${file_size_blk}
			echo "mtd: copy completed"

			rkimgtest mtd 2

			echo " "
			echo "please remove USB"
			echo ""
			echo "******************************************"
		else
			echo "******************************************"
			echo "usb: there is no flash update file"
			echo "******************************************"
		fi
	fi

	echo "update rootfs"

	if test -e usb 0:1 update.img.0 ; then
	    echo "******************************************"
	    echo "usb: there is update file"

	    #turn on red led
	    gpio clear gpio211
		gpio clear gpio411

	    #turn off blue led
	    gpio set gpio212
		gpio set gpio412
	EOF

	i=0
	while [ "$i" -lt $fileCnt ]; do
		cat >> $BUILD_PATH/boot.cmd <<- EOF

	    size usb 0:1 update.img.$i
	    echo "usb: part $i image size: \${filesize} bytes"
	    echo "usb: wait for copy part $i image to DDR"
	    fatload usb 0:1 \${load_addr0} update.img.$i
	    echo "usb: part $i copy complete"
	    setexpr file_size_blk \${filesize} / 0x200
	    echo "emmc: part $i image block size: \${file_size_blk}"
	    echo "emmc: wait for copy part $i image to eMMC"
	    mmc write \${load_addr0} \${load_addr_part_$i} \${file_size_blk}
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
		gpio set gpio411

	    #turn on blue led
	    gpio clear gpio212
		gpio clear gpio412

	    while true ; do ;
	    gpio set gpio212 &&
		gpio set gpio412 &&
	    usb reset &&
	    gpio clear gpio212 &&
		gpio clear gpio412 &&
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
 	sudo rm -f update.zip
	zip -s 1900m -r update.zip update.img.* boot.scr flash.img

} #CreateUsbFlashUpdate
########################################################
Main "$@"
