#!/bin/bash 
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later
#
# This script is started by iapg_init_kiosk.sh. 
# It starts a chromium-browser kiosk which will "talk to" the picture server via the IP address and port given in iapg_kiosk.conf.
# It will wait until iapg_kiosk.conf exists and the picture server can be pinged.
# When iapg_kiosk.conf has been updated the kiosk will be rebooted.

g_base=$HOME/iapg-main
g_etc_dir=${g_base}/etc
g_html_dir=${g_base}/html
g_var_dir=${g_base}/var
g_log_dir=${g_var_dir}/log

g_fi_server_conf=${g_etc_dir}/iapg_server.conf
g_fi_clublist=${g_etc_dir}/clublist.conf
g_fi_kiosk_conf=${g_etc_dir}/iapg_kiosk.conf
suff=$(date +%Y-%m-%d_%H-%M-%S)
g_fi_log=${g_log_dir}"/iapg_kiosk_"${suff}".log"	#Used by logit.

g_status_server_type="display_server"
g_status_server_port_nr=53000

g_local_host="127.0.0.1"

g_legal_club_range="club-1 ... club-99"
g_legal_port_range="53001, 53002, ... 53999"
declare -i g_nr_ping_failures=0
declare -i keep_logs_days=7
find "${g_log_dir}" -name "*.log" -type f -mtime +${keep_logs_days} -exec rm -v {} \;

source ${g_base}/iapg_functions.sh

function is_ip_valid()
{
    local  ip=$1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
			return 1
		fi
    fi
    return 0
}


function get_iapg_kiosk_config_if_proper()
{
	logit "get_iapg_kiosk_config_if_proper"	

	if [ ! -f ${g_fi_kiosk_conf} ]; then
		log_user_err "Fix the config ${g_fi_kiosk_conf}. It is missing" 
		return 0
	fi

	# Defaults
	g_addr_server="192.168.0.250"
	g_port_nr="53001"
	g_club_id="club-1"
	g_window_size=""
	g_wi_size=""
	g_monitor_network_and_reboot="y"
	
	err_found=0
	while read -r line ; do
		trimmed_line=$(echo ${line}|sed 's/#.*//g' |sed 's/[[:space:]]\+//g' ) #Remove comments and whitespace.
		if [[ "${trimmed_line}" != "" ]] ; then
			if [[ "${trimmed_line}" =~ "addr_server" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				is_ip_valid $s
				iret=$?
				if [[ ${iret} -eq 0 ]]; then
					log_user_err "addr_server in $g_fi_kiosk_conf is $s which is a bad IP Address." 
					err_found=1
				else
					g_addr_server=$s
				fi
			fi	

			if [[ "${trimmed_line}" =~ "window_size" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')	
				if ! [[ $s =~ ^[0-9],[0-9]+$ ]]; then
					log_user_err "window_size in $g_fi_kiosk_conf is $s but must be like: 1920,1080" 
					err_found=1
				else
					g_window_size=$s
				fi
			fi

			if [[ "${trimmed_line}" =~ "port_nr_for_this_kiosk" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				if ! [[ $s =~ ^[0-9]+$ ]]; then
					log_user_err "port_nr_for_this_kiosk in $g_fi_kiosk_conf is ${s} but must be a number." 
					err_found=1
				else
					if [[ ${s} -lt 53001 ]] || [[ ${s} -gt 53991 ]]; then
						log_user_err "port_nr_for_this_kiosk in $g_fi_kiosk_conf is $s but must be [53001-53991]." 
						err_found=1
					else
						g_port_nr=$s
					fi				
				fi
			fi
			
			if [[ "${trimmed_line}" =~ "monitor_network_and_reboot" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				if ! [[ ${s} == "y" ]] || [[ ${s} == "n" ]]; then
					log_user_err "monitor_network_and_reboot in $g_fi_kiosk_conf is ${s} but must be y or n." 
					err_found=1
				else
					g_monitor_network_and_reboot=$s
				fi
			fi

			if [[ "${trimmed_line}" =~ "club_id" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				nr=$(echo $s | awk -Fclub- '{print $2}')
				if [[ !( $nr =~ ^[0-9]{1,2} ) ]]; then
					log_user_err "Invalid club parameter. The club_id: $s is not in the range $g_legal_club_range."
					err_found=1
				else
					if [ ! -d ${g_html_dir}/${s} ]; then
						log_user_err "Invalid club parameter. The club-directory: "${s}" does not exist." 
						err_found=1
					else
						g_club_id=$s
					fi	
				fi
			fi
			
		fi
	done < $g_fi_kiosk_conf

	if [[ ${err_found} -eq 1 ]]; then	
		return 0
	fi
	
	if [[ ${g_window_size} != "" ]]; then
		g_wi_size=" --window-size="${g_window_size}
	fi	
	
	g_display_page="http://"${g_addr_server}":"${g_port_nr}"/show.html"  
	logit "addr_server = $g_addr_server"	
	logit "club_id = $g_club_id"	
	logit "port_nr_for_this_kiosk = $g_port_nr"	
	logit "window_size = $g_window_size"	
	logit "display_page = $g_display_page"
	logit "monitor_network_and_reboot = ${g_monitor_network_and_reboot}"
	return 1
}


function is_something_modified()
{	
	local diff
	if [ -f ${g_fi_kiosk_conf} ]; then
		g_ts_conf=$(date -r ${g_fi_kiosk_conf} +%s)
		diff=$(($g_ts_conf - $g_last_ts_conf))
		if [[ ${diff} -gt 0 ]]; then
			return 1
		fi
	fi
}


function wait_until_proper_configs()
{
	declare -i local loop_nr=0
	declare -i local try_now=1
	declare -i local config_proper=0

	if [ -f ${fi_config_status_ok} ]; then
		rm $fi_config_status_ok
	fi
	if [ -f ${fi_config_error} ]; then
		rm $fi_config_error
	fi
	
	log_run_status_logit "wait_until_proper_configs: Waiting for all configs in ${g_fi_kiosk_conf} to be properly updated."
	
	while [ 1 -eq 1 ]
	do
		loop_nr=$loop_nr+1
		n=$((loop_nr % ${log_modif_check_counter}))
		if [[ ${n} -eq 0 ]]; then
			log_run_status_logit "wait_until_proper_configs ${g_fi_kiosk_conf} loop_nr=${loop_nr}  config_proper=${config_proper}."
		fi
		
		if [[ ${try_now} -eq 1 ]]; then
			log_user_err "Validates configuration." 
			
			get_iapg_kiosk_config_if_proper
			config_proper=$?
			if [[ ${config_proper} -eq 1 ]]; then
				echo "${g_fi_kiosk_conf} seems proper." > $fi_config_status_ok
				log_run_status_logit "${g_fi_kiosk_conf} seems proper."
				if [ -f ${fi_config_error} ]; then
					rm $fi_config_error
				fi
				return 1
			fi			
		fi
		
		# Loop until an update has happened.
		sleep 10
		is_something_modified
		iret=$?
		if [[ ${iret} -eq 1 ]]; then
			try_now=1
		else
			try_now=0
		fi
	done
}


function wait_for_network_to_be_up_or_reboot()
{
	declare -i local loop=1
	declare -i local nr_sec=0
	declare -i local kiosk_started=0	
	declare -i local reboot_now=0
	local dt
	local s
	declare -i local reboot_when_network_not_up_after=86400  # A day

	reboot_when_network_not_up_after=$1	
	
	# Loop until the network is up and the system has got an address.				
	while [ 1 -eq 1 ]
	do
		if_up=$(ip a | grep -v 127.0 | grep "inet " | grep -v "::1/128")

		if [[ "${if_up}" == *"inet "* ]]; then
			log_run_status_logit "wait_for_network_to_be_up_or_reboot: Link is up and the system has an address ${loop} trials" 
			if [[ ${kiosk_started} -eq 1 ]]; then
				reboot_now=1
			else
				return 1
			fi
		fi
		
		if [ $((loop % 10)) -eq 0 ]; then
			log_run_status_logit "wait_for_network_to_be_up_or_reboot: Still not any link up. Trial nr=${loop}" 
		fi
		
		loop=${loop}+1
		sleep 5
		nr_sec=${nr_sec}+5

		if [[ ${kiosk_started} -eq 0 ]]; then
			if [[ ${nr_sec} -gt 60 ]]; then
				# Not up. Start the server with an error page. 
				log_run_status_logit "wait_for_network_to_be_up_or_reboot: The system will be rebooted when the network is up OR if the network is still not up after ${reboot_when_network_not_up_after} seconds." 
				log_kiosk_network_start_err_logit "The network is not available. The kiosk has not got an address. Maybe the WiFi got the wrong password when the boot-image was created"
				g_display_page="http://"${g_local_host}":53000/kiosk_startup_problems.html" 
				
				server_up=0					
				start_the_kiosk
				kiosk_started=1	
			fi
		fi  
		
		if [[ ${nr_sec} -gt ${reboot_when_network_not_up_after} ]]; then
			reboot_now=1
		fi
		
		if [[ ${reboot_now} -eq 1 ]]; then	
			s="Still not any link up after ${nr_sec} s."
			dt=$(date +"%Y-%m-%d_%H:%M:%S")
			echo "${dt} iapg_kiosk wait_for_network_to_be_up_or_reboot: ${s} Request to reboot now." >> $g_fi_kiosk_reboot_log
			echo "${dt} iapg_kiosk wait_for_network_to_be_up_or_reboot: Request to reboot now" > $g_fi_request_kiosk_reboot		
			sleep 60	# Just wait for the reboot			
		fi
		
	done
}


function wait_for_picture_server_to_be_up()
{
	declare -i local loop=1
	declare -i local nr_trials=$1
	
	log_run_status_logit "wait_for_picture_server_to_be_up: Waiting for a ping response from the picture server ${g_addr_server}." 
	
	while [ 1 -eq 1 ]
	do
		ping_res=$(ping -n -c1 "${g_addr_server}")
		ping_succ=$(echo ${ping_res} | grep "1 received")	
		if [[ ${ping_succ} != "" ]]; then
			log_run_status_logit "Got a ping response from the picture server ${g_addr_server}  after ${loop} trials" 
			return 1
		fi
		
		if [ $((loop % 10)) -eq 0 ]; then
			log_run_status_logit "Still not any response from the picture server ${g_addr_server}. Trial nr=${loop}"
		fi

		if [[ ${loop} -eq ${nr_trials} ]]; then
			return 0
		fi
		
		loop=${loop}+1
		sleep 10
		
	done
}


function start_the_kiosk()
{
	logit "start_the_kiosk"

	if [[ ${server_up} -eq 1 ]]; then
		get_iapg_kiosk_config_if_proper  
	fi

	# Chromium shall have "exited cleanly".
	sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' $HOME'/.config/chromium/Default/Preferences'
	sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' $HOME'/.config/chromium/Default/Preferences'

	logit "Before start of chromium-browser. ${g_display_page} "

	chromium-browser ${g_display_page} ${g_wi_size} --kiosk --incognito --noerrdialogs --disable-infobars --disk-cache-dir=/dev/null &

	log_run_status_logit "Kiosk chromium-browser started."
}


function start_status_server()
{
	suff=$(date +%Y-%m-%d_%H-%M-%S)
	fi_log_server=${g_log_dir}/iapg_status_server_stdout_err_${suff}.log
	cmd="node ${g_base}/iapg_status_server.js ${g_status_server_port_nr} ${g_status_server_type} > ${fi_log_server}"	
	logit "To be started: ${cmd}"
	node ${g_base}/iapg_status_server.js  ${g_status_server_port_nr} ${g_status_server_type}  > ${fi_log_server} 2>&1 &	
}			


function if_wifi_off_request_kiosk_reboot()
{
	declare -i local loop=0
	declare -i local reboot_when_nr_ping_failures=1000
	reboot_when_nr_ping_failures=$1
		
	while [ ${loop} -lt 3 ]
	do
		ping_res=$(ping -n -c1 "${g_addr_router}")
		ping_succ=$(echo ${ping_res} | grep "1 received")	
		if [[ ${ping_succ} != "" ]]; then
			if [ -f ${g_fi_active_router} ]; then
				rm ${g_fi_active_router}
			fi	
			g_nr_ping_failures=0
			return 1
		fi
				
		loop=${loop}+1
		sleep 2
	done

	g_nr_ping_failures=${g_nr_ping_failures}+1	
	s="The router ${g_addr_router} does not respond to ping. trial=${g_nr_ping_failures}."
	log_router_status_logit ${s}
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} iapg_kiosk: ${s} Too early to request a reboot." >> $g_fi_kiosk_reboot_log

	if [[ ${g_monitor_network_and_reboot} == "y" ]]; then
		if [[ ${g_nr_ping_failures} -le ${reboot_when_nr_ping_failures} ]]; then		
			echo "${dt} iapg_kiosk: ${s} Request to reboot now." >> $g_fi_kiosk_reboot_log
			echo "${dt} iapg_kiosk: Request to reboot now" > $g_fi_request_kiosk_reboot
			sleep 60	# Just wait for the reboot
		fi
	fi

	return 0
}


function try_webserver_up()
{
	# Make several trials. The server could just have booted and respond to pings but the webservers are not yet started.
	declare -i loop_nr=1	
	while [ ${loop_nr} -lt 5 ]
	do
		logit "try_webserver_up: ${loop_nr}, the monitor-port 53000"
		s=$(curl http://${g_addr_server}:53000/index.html )
		s1=$(echo $s|grep "content")
		if [[ ${s1} == ""  ]]; then
			logit "try_webserver_up: monitor-port 53000 is not responding. Wait 3 s"
			# Nothing back.
			loop_nr=$loop_nr+1
			sleep 3
		fi
		logit "try_webserver_up: ${loop_nr} monitor-port 53000 responds, webserver up"
		return 1
	done
	logit "try_webserver_up: monitor-port 53000 is still dead."
	return 0
}


function try_server_up()
{
	try_up_ctr=$try_up_ctr+1
	declare -i local reboot_now=0
	
	wait_for_picture_server_to_be_up 6			# Wait for ping ok or ping timeout. 
	iret=$?
	if [[ ${iret} -eq 1 ]]; then
		logit "restart_the_kiosk now. The picture server ${g_addr_server} responds to ping and should be available now."	
		reboot_now=1
	fi
	if [[ ${try_up_ctr} -eq ${reboot_after_nr_trials} ]]; then		
		logit "restart_the_kiosk now to see if the picture server ${g_addr_server} could be available."
		reboot_now=1
	fi
	
	log_kiosk_start_err_logit "The Picture server ${g_addr_server} does not respond to ping. nr_trials=${try_up_ctr} (minutes). The kiosk will reboot after ${reboot_after_nr_trials} trials. "
	
	if [[ ${reboot_now} -eq 1 ]]; then	
		dt=$(date +"%Y-%m-%d_%H:%M:%S")
		echo "${dt} iapg_kiosk: The picture server is/was not avaiable. Request to reboot now." >> $g_fi_kiosk_reboot_log
		echo "${dt} iapg_kiosk: Request to reboot now" > $g_fi_request_kiosk_reboot
		sleep 60	# Just wait for the reboot
	fi
}


function restart_the_kiosk_when_the_webserver_comes_up()
{
	try_webserver_up
	iret=$?
	if [[ ${iret} -eq 0 ]]; then
		log_kiosk_start_err_logit "The ${g_addr_server} is not a picture server. (or the webserver is dead)"
		log_run_status_logit "The ${g_addr_server} is not a picture server. (or the webserver is dead)"
	else
		dt=$(date +"%Y-%m-%d_%H:%M:%S")
		echo "${dt} iapg_kiosk: The webserver in the picture server was not avaiable but it is now. Request to reboot now." >> $g_fi_kiosk_reboot_log
		echo "${dt} iapg_kiosk: Request to reboot now" > $g_fi_request_kiosk_reboot
		sleep 60	# Just wait for the reboot	
	fi
}


function hide_the_cursor()
{
	# Before wayland.
	# Do not waste cpu cycles. Remove the mouse pointer only every 10th second.
	# unclutter -idle 10 -root &  	 
	#s=$(echo "$XDG_SESSION_TYPE")
	#xset -dpms
	#xset s off
	#xset s noblank
		
	# This is for Wayland
	if [ -f /usr/share/icons/PiXflat/cursors/left_ptr ]; then
		logit "hide_the_cursor: Remove the cursor, rename /usr/share/icons/PiXflat/cursors/left_ptr"
		sudo mv -v /usr/share/icons/PiXflat/cursors/left_ptr /usr/share/icons/PiXflat/cursors/left_ptr.bak
		if [ -f /usr/share/icons/PiXflat/cursors/left_ptr ]; then
			logit "hide_the_cursor: Remove the cursor, rename failed."
		fi
	fi
}


#######################################
logit "Started."
declare -i log_modif_check_counter=360

# Delete the two files in the etc dir that were installed but which are only used in a picture server.
if [ -f ${g_fi_server_conf} ]; then
	rm ${g_fi_server_conf}
fi
if [ -f ${g_fi_clublist} ]; then
	rm ${g_fi_clublist}
fi

if [ -f ${fi_kiosk_start_err} ]; then
	rm $fi_kiosk_start_err
fi
if [ -f ${fi_kiosk_network_start_err} ]; then
	rm $fi_kiosk_network_start_err
fi

hide_the_cursor

g_monitor_network_and_reboot="y"              #initial value

start_status_server

wait_for_network_to_be_up_or_reboot 1200	# If the network is not up after latest 1200s a reboot will be done.

wait_for_router_to_be_up

wait_for_config_file $g_fi_kiosk_conf
g_last_ts_conf=$(date +%s)		# This time stamp will be used to see if the config has been updated later on. 

wait_until_proper_configs

wait_for_picture_server_to_be_up 6	# Do not start the kiosk until the picture server is up. Wait, a while, until it responds to pings.
iret=$?
if [[ ${iret} -eq 0 ]]; then
	# Not up. Start the kiosk with an error page. 
	log_run_status_logit "The picture server ${g_addr_server} is not available."
	g_display_page="http://"${g_local_host}":53000/kiosk_startup_problems.html"  
	server_up=0	
else
	server_up=1	
	try_webserver_up
	iret=$?
	if [[ ${iret} -eq 0 ]]; then
		log_kiosk_start_err_logit "The ${g_addr_server} is not a picture server."
		log_run_status_logit "The ${g_addr_server} is not a picture server."
		g_display_page="http://"${g_local_host}":53000/kiosk_startup_problems.html"  
		server_up=2	  # To let the next loop continue until something is modified.
	fi
fi

start_the_kiosk

logit "Eternal check every 10s for a modified ${g_fi_kiosk_conf}. Restarts the kiosk as soon as the file is modified."
declare -i reboot_after_nr_trials=60	# About an hour
declare -i try_up_ctr=0
declare -i loop_nr=0
while [ 1 -eq 1 ]
do
	loop_nr=$loop_nr+1
	n=$((loop_nr % ${log_modif_check_counter}))
	if [[ ${n} -eq 0 ]]; then
		logit "Are configurations modified check counter : ${loop_nr}."
	fi

	if_wifi_off_request_kiosk_reboot 7	# Number of ping failure cycles before a reboot. 7 => about one minute
	
	is_something_modified
	iret=$?
	if [[ ${iret} -eq 1 ]]; then
		wait_until_proper_configs	
		logit "restart_the_kiosk"
		dt=$(date +"%Y-%m-%d_%H:%M:%S")
		echo "${dt} iapg_kiosk: ${g_fi_kiosk_conf} is updated. Request to reboot now." >> $g_fi_kiosk_reboot_log
		echo "${dt} iapg_kiosk: Request to reboot now" > $g_fi_request_kiosk_reboot
	fi

	if [[ ${server_up} -eq 2 ]]; then
		restart_the_kiosk_when_the_webserver_comes_up
	fi

	if [[ ${server_up} -eq 0 ]]; then
		try_server_up
	fi
	
	sleep 10
done	

