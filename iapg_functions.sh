#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

# Functions used by iapg_kiosk.sh and iapg_start_servers.sh. 

g_base=$HOME/iapg-main
g_var_dir=${g_base}/var
g_log_dir=${g_base}/var/log

fi_config_error=${g_log_dir}"/a_config_error.txt"
fi_config_status_ok=${g_log_dir}"/a_config_status.txt"
fi_start_status=${g_log_dir}"/a_start_status.txt"
fi_kiosk_start_err=${g_log_dir}"/a_kiosk_start_err.txt"
fi_kiosk_network_start_err=${g_log_dir}"/a_kiosk_network_start_err.txt"
fi_info_started_clubs=${g_log_dir}"/a_conf_info_started_clubs.txt"
fi_started_clubs=${g_log_dir}"/a_conf_started_clubs.txt"

g_fi_active_router=${g_log_dir}"/active_router.txt"
g_fi_request_kiosk_reboot=${g_var_dir}"/request_kiosk_reboot.txt"
g_fi_kiosk_reboot_log=${g_log_dir}"/kiosk_reboot_log.txt"

g_legal_club_range="club-1 ... club-99"

g_ping=$(which "ping")

function logit()
{
	local dt
	log_line=$@
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} ${log_line}" >> $g_fi_log		
}


function log_kiosk_start_err_logit()
{
	local dt
	log_line=$@	
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} ${log_line}" > $fi_kiosk_start_err
	logit "${log_line}"
}


function log_kiosk_network_start_err_logit()
{
	local dt
	log_line=$@	
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} ${log_line}" > $fi_kiosk_network_start_err
	logit "${log_line}"
}



function log_run_status_logit()
{
	local dt
	log_line=$@	
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} ${log_line}" > $fi_start_status
	logit "${log_line}"
}


function log_router_status_logit()
{
	local dt
	log_line=$@	
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} ${log_line}" > $g_fi_active_router
	logit "${log_line}"
}


function log_user_err()
{
	local dt
	log_line=$@	
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo -e "${dt} ${log_line}" >> $fi_config_error	
	logit "${log_line}"
}



function wait_for_router_to_be_up()
{
	declare -i local loop=1
		
	g_addr_router=$(/sbin/ip route | grep -m1 "default" | awk '{ print $3 }' )
	
	log_run_status_logit "wait_for_router_to_be_up: Waiting for a ping response from the router ${g_addr_router}"
	
	while [ 1 -eq 1 ]
	do
		ping_res=$(${g_ping} -n -c2 ${g_addr_router})
		ping_succ=$(echo ${ping_res} | grep "2 received")
				
		if [[ ${ping_succ} != "" ]]; then
			log_run_status_logit "wait_for_router_to_be_up: Got a ping response from the router ${g_addr_router} after ${loop} trials"
			return
		fi
		
		if [ $((loop % 10)) -eq 0 ]; then
			log_run_status_logit "wait_for_router_to_be_up: Still not any response from the router ${g_addr_router}. Trial nr=${loop}"
		fi
		
		loop=${loop}+1
		sleep 10
	done
}


function wait_for_config_file()
{
	declare -i local loop=1
	local i
	local fi_conf
	
	fi_conf=$1
	
	log_run_status_logit "wait_for_config_file: Waiting until the ${fi_conf} exists." 
	
	while [ 1 -eq 1 ]
	do
		if [ -f ${fi_conf} ]; then
			log_run_status_logit "wait_for_config_file: ${fi_conf} found after ${loop} trials" 
			return
		fi
		
		if [ $((loop % 60)) -eq 0 ]; then
			log_run_status_logit "wait_for_config_file: Still not any ${fi_conf}. Trial nr=${loop}"
		fi
		
		loop=${loop}+1
		sleep 10
	done
}

