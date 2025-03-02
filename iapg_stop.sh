#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later
#
# This script is run by iapg_server_starter.sh. 
# It can stop the picture servers, iapg_server.js, and the control script iapg_server_starter.sh.
# It runs iapg_click_stats_to_csv.sh for a stopped server.
#
# The following command will stop the servers and the control program: 
# iapg_stop.sh
#
# The next command will only stop servers:
# iapg_stop.sh stop_all_servers|club-to-stop

g_bash=$(which "bash")
g_base=$HOME/iapg-main
fi_tmp1=${g_base}/var/log/ps.tmp

echo "$(date +"%y%m%d-%H%M%S") iapg_stop.sh nr_args=$# args=$@"
ps ax|grep "node .*iapg_server.js"|grep -v grep > $fi_tmp1		# Stop all servers	
if [ $# -eq 1 ]; then
	arg=$1
else
	arg=""
fi
	
function stop_servers()
{
	while read line ; do
		pid=$(echo ${line} | awk '{print $1}')
		kill ${pid}
		echo "$(date +"%y%m%d-%H%M%S") PID=${pid} killed. ${line}"
		
		port_nr=$(echo ${line} | awk '{print $(NF-1)}')
		$g_bash ${g_base}/iapg_click_stats_to_csv.sh $port_nr 
	done < $fi_tmp1
	rm -f ${fi_tmp1}
}


function stop_server_starter()
{
	ps ax|grep "iapg_server_starter.sh"|grep -v grep > $fi_tmp1		
	while read line ; do
		pid=$(echo ${line} | awk '{print $1}')
		kill ${pid}
		echo "$(date +"%y%m%d-%H%M%S") PID=${pid} killed. ${line}"
	done < $fi_tmp1
	rm -f ${fi_tmp1}
}


function stop_status_server()
{
	ps ax|grep "iapg_status_server.js"|grep -v grep > $fi_tmp1		
	while read line ; do
		pid=$(echo ${line} | awk '{print $1}')
		kill ${pid}
		echo "$(date +"%y%m%d-%H%M%S") PID=${pid} killed. ${line}"
	done < $fi_tmp1
	rm -f ${fi_tmp1}
}

#######################################
ps ax|grep "node .*iapg_server.js"|grep -v grep > $fi_tmp1		# Stop all servers	
if [[ $arg != "" ]]; then		# 
	if [[ ${arg} != "stop_all_servers" ]]; then
		ps ax|grep "node .*iapg_server.js.*"${arg}|grep -v grep > $fi_tmp1		# Stop only servers for one club.
	fi
	stop_servers
else
	stop_servers
	stop_server_starter
	stop_status_server
fi


