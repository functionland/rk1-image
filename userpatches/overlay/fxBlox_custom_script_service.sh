#!/bin/bash


addUser()
{
	echo "Creat User"

	# create user
	RealUserName=$ARMBIAN_USER_NAME
	RealName=$ARMBIAN_USER_NAME
	password=$ARMBIAN_USER_PASSWORD

	adduser --quiet --disabled-password --home /home/"$RealUserName" --gecos "$RealName" "$RealUserName"
	(
		echo "$password"
		echo "$password"
	) | passwd "$RealUserName" > /dev/null 2>&1

	# mkdir -p /home/$ARMBIAN_USER_NAME/
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
} # addUser



if [[ -f /root/.fxBlox_custom_script_service ]]; then

	rm -f /root/.fxBlox_custom_script_service

	# read variable from config file
	source /usr/bin/fula/config


	# disable autologin
	rm -f /etc/systemd/system/getty@.service.d/override.conf
	rm -f /etc/systemd/system/serial-getty@.service.d/override.conf
	systemctl daemon-reload

	declare desktop_dm="none"
	declare -i desktop_is_sddm=0 desktop_is_lightdm=0 desktop_is_gdm3=0
	if [[ -f /usr/bin/sddm ]]; then
		desktop_dm="sddm"
		desktop_is_sddm=1
	fi
	if [[ -f /usr/sbin/lightdm ]]; then
		desktop_dm="lightdm"
		desktop_is_lightdm=1
	fi
	if [[ -f /usr/sbin/gdm3 ]]; then
		desktop_dm="gdm3"
		desktop_is_gdm3=1
	fi

	echo -e "\nWaiting for system to finish booting ..."
	systemctl is-system-running --wait > /dev/null

	# enable hiDPI support
	if [[ "$(cut -d, -f1 < /sys/class/graphics/fb0/virtual_size 2> /dev/null)" -gt 1920 ]]; then
		# lightdm
		[[ -f /etc/lightdm/slick-greeter.conf ]] && echo "enable-hidpi = on" >> /etc/lightdm/slick-greeter.conf
		# xfce
		[[ -f /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ]] && sed -i 's|<property name="WindowScalingFactor" type="int" value=".*|<property name="WindowScalingFactor" type="int" value="2">|g' /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

		# framebuffer console larger font
		setfont /usr/share/consolefonts/Uni3-TerminusBold32x16.psf.gz
	fi

	clear

	echo -e "Welcome to \e[1m\e[97m${VENDOR}\x1B[0m! \n"
	echo -e "Documentation: \e[1m\e[92m${VENDORDOCS}\x1B[0m | Community support: \e[1m\e[92m${VENDORSUPPORT}\x1B[0m\n"
	GET_IP=$(bash /etc/update-motd.d/30-armbian-sysinfo | grep IP | sed "s/.*IP://" | sed 's/^[ \t]*//')
	[[ -n "$GET_IP" ]] && echo -e "IP address: $GET_IP\n"


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


	addUser;


	#set_timezone_and_locales;


	# if [[ ${USER_SHELL} == zsh ]]; then
	# 	printf "\nYou selected \e[0;91mZSH\x1B[0m as your default shell. If you want to use it right away, please logout and login! \n\n"
	# fi

	# re-enable passing locale environment via ssh
	sed -e '/^#AcceptEnv LANG/ s/^#//' -i /etc/ssh/sshd_config
	# restart sshd daemon
	systemctl reload ssh.service

	# rpardini: hacks per-dm, very much legacy stuff that works by a miracle
	if [[ "${desktop_dm}" == "lightdm" ]] && [ -n "$RealName" ]; then

		# 1st run goes without login
		mkdir -p /etc/lightdm/lightdm.conf.d
		cat <<- EOF > /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf
			[Seat:*]
			autologin-user=$RealUserName
			autologin-user-timeout=0
			user-session=xfce
		EOF

		# select gnome session (has to be first or it breaks budgie/cinnamon desktop autologin and user-session)
		# @TODO: remove this, gnome should use gdm3, not lightdm
		[[ -x $(command -v gnome-session) ]] && sed -i "s/user-session.*/user-session=ubuntu/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v gnome-session) ]] && sed -i "s/user-session.*/user-session=ubuntu/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select awesome session
		[[ -x $(command -v awesome) ]] && sed -i "s/user-session.*/user-session=awesome/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v awesome) ]] && sed -i "s/user-session.*/user-session=awesome/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select budgie session
		[[ -x $(command -v budgie-desktop) ]] && sed -i "s/user-session.*/user-session=budgie-desktop/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v budgie-desktop) ]] && sed -i "s/user-session.*/user-session=budgie-desktop/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select cinnamon session
		[[ -x $(command -v cinnamon) ]] && sed -i "s/user-session.*/user-session=cinnamon/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v cinnamon) ]] && sed -i "s/user-session.*/user-session=cinnamon/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select deepin session
		[[ -x $(command -v deepin-wm) ]] && sed -i "s/user-session.*/user-session=deepin/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v deepin-wm) ]] && sed -i "s/user-session.*/user-session=deepin/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select ice-wm session
		[[ -x $(command -v icewm-session) ]] && sed -i "s/user-session.*/user-session=icewm-session/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v icewm-session) ]] && sed -i "s/user-session.*/user-session=icewm-session/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select i3 session
		[[ -x $(command -v i3) ]] && sed -i "s/user-session.*/user-session=i3/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v i3) ]] && sed -i "s/user-session.*/user-session=i3/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select lxde session
		[[ -x $(command -v startlxde) ]] && sed -i "s/user-session.*/user-session=LXDE/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v startlxde) ]] && sed -i "s/user-session.*/user-session=LXDE/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select lxqt session
		[[ -x $(command -v startlxqt) ]] && sed -i "s/user-session.*/user-session=lxqt/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v startlxqt) ]] && sed -i "s/user-session.*/user-session=lxqt/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select mate session
		[[ -x $(command -v mate-wm) ]] && sed -i "s/user-session.*/user-session=mate/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v mate-wm) ]] && sed -i "s/user-session.*/user-session=mate/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select plasma wayland session # @TODO: rpardini: dead code? kde-plasma desktop should use sddm, not lightdm.
		[[ -x $(command -v plasmashell) ]] && sed -i "s/user-session.*/user-session=plasmawayland/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v plasmashell) ]] && sed -i "s/user-session.*/user-session=plasmawayland/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select sway wayland session
		[[ -x $(command -v sway) ]] && sed -i "s/user-session.*/user-session=sway/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v sway) ]] && sed -i "s/user-session.*/user-session=sway/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		# select xmonad session
		[[ -x $(command -v xmonad) ]] && sed -i "s/user-session.*/user-session=xmonad/" /etc/lightdm/lightdm.conf.d/11-armbian.conf
		[[ -x $(command -v xmonad) ]] && sed -i "s/user-session.*/user-session=xmonad/" /etc/lightdm/lightdm.conf.d/22-armbian-autologin.conf

		ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

		if [[ -f /var/run/resize2fs-reboot ]]; then
			# Let the user reboot now otherwise start desktop environment
			printf "\n\n\e[0;91mWarning: a reboot is needed to finish resizing the filesystem \x1B[0m \n"
			printf "\e[0;91mPlease reboot the system now \x1B[0m \n\n"
		else
			echo -e "\n\e[1m\e[39mNow starting desktop environment...\x1B[0m\n"
			sleep 1
			service lightdm start 2> /dev/null
			if [ -f /root/.desktop_autologin ]; then
				rm /root/.desktop_autologin
			else
				systemctl -q enable armbian-disable-autologin.timer
				systemctl start armbian-disable-autologin.timer
			fi
			# logout if logged at console
			who -la | grep root | grep -q tty1 && exit 1
		fi

	elif [[ "${desktop_dm}" == "gdm3" ]] && [ -n "$RealName" ]; then
		# 1st run goes without login
		mkdir -p /etc/gdm3
		cat <<- EOF > /etc/gdm3/custom.conf
			[daemon]
			AutomaticLoginEnable = true
			AutomaticLogin = $RealUserName
		EOF

		ln -sf /lib/systemd/system/gdm3.service /etc/systemd/system/display-manager.service

		if [[ -f /var/run/resize2fs-reboot ]]; then
			# Let the user reboot now otherwise start desktop environment
			printf "\n\n\e[0;91mWarning: a reboot is needed to finish resizing the filesystem \x1B[0m \n"
			printf "\e[0;91mPlease reboot the system now \x1B[0m \n\n"
		else
			echo -e "\n\e[1m\e[39mNow starting desktop environment...\x1B[0m\n"
			sleep 1
			service gdm3 start 2> /dev/null
			if [ -f /root/.desktop_autologin ]; then
				rm /root/.desktop_autologin
			else
				(
					sleep 20
					sed -i "s/AutomaticLoginEnable.*/AutomaticLoginEnable = false/" /etc/gdm3/custom.conf
				) &
			fi
			# logout if logged at console
			who -la | grep root | grep -q tty1 && exit 1
		fi
	elif [[ "${desktop_dm}" == "sddm" ]] && [ -n "$RealName" ]; then
		# No hacks for sddm. User will have to input password again, and have  chance to choose session wayland
		echo -e "\n\e[1m\e[39mNow starting desktop environment via ${desktop_dm}...\x1B[0m\n"
		systemctl enable --now sddm
	else
		# no display manager detected
		# Display reboot recommendation if necessary
		if [[ -f /var/run/resize2fs-reboot ]]; then
			printf "\n\n\e[0;91mWarning: a reboot is needed to finish resizing the filesystem \x1B[0m \n"
			printf "\e[0;91mPlease reboot the system now \x1B[0m \n\n"
		fi
	fi

	reboot
fi
