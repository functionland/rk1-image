#!/bin/bash

if [[ -f /root/.fxBlox_custom_script_service ]]; then
	# read variable from config file
	source /usr/bin/fula/config

	usermod -aG docker "$RealUserName"

	rm -f /root/.fxBlox_custom_script_service
	sync
	sleep 1
	systemctl --no-reload disable fxBlox_custom_script_service.service
	rm -rf /etc/systemd/system/fxBlox_custom_script_service.service 
	#reboot
fi
