#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

# This script it is started by systemd as the root user. It reboots the kiosk on a request in a file from the fg user. 

g_base=/home/fg/iapg-main
source ${g_base}/iapg_functions.sh

g_base=/home/fg/iapg-main

g_var_dir=${g_base}/var
g_log_dir=${g_var_dir}/log

suff=$(date +%Y-%m-%d_%H-%M-%S)
g_fi_kiosk_reboot_log=${g_log_dir}"/kiosk_reboot_log.txt"
g_fi_request_kiosk_reboot=${g_var_dir}"/request_kiosk_reboot.txt"
g_fi_log=${g_log_dir}"/iapg_kiosk_rebooter_"${suff}".log"		#Used by logit.

#######################################
logit "Started."
declare -i check_counter=360

if [ -f ${g_fi_request_kiosk_reboot} ]; then
	logit "Delete an old ${g_fi_request_kiosk_reboot}"
	rm ${g_fi_request_kiosk_reboot}
fi

logit "Eternal check for a request to reboot."
declare -i loop_nr=0
declare -i n=0

while [ 1 -eq 1 ]
do
	loop_nr=$loop_nr+1
	n=$((loop_nr % ${check_counter}))
	if [[ ${n} -eq 0 ]]; then
		logit "Request check counter: ${loop_nr}."
	fi
	
	if [ -f ${g_fi_request_kiosk_reboot} ]; then
		logit "Found ${g_fi_request_kiosk_reboot}"
		dt=$(date +"%Y-%m-%d_%H:%M:%S")
		echo "${dt} iapg_kiosk_rebooter: found ${g_fi_request_kiosk_reboot}" >> $g_fi_kiosk_reboot_log
		cat ${g_fi_request_kiosk_reboot} >> $g_fi_kiosk_reboot_log
		sleep 2
		rm ${g_fi_request_kiosk_reboot} 

		sleep 2
		dt=$(date +"%Y-%m-%d_%H:%M:%S")
		echo "${dt} iapg_kiosk_rebooter: Reboots now." >> $g_fi_kiosk_reboot_log
		reboot now
	fi
	
	sleep 10
done	

