#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

# This script is run by iapg_stop.sh. It runs iapg_clicks_to_csv.py to create csv files of json files with click statistics.
# It also deletes old files.

echo "$(date +"%Y-%m-%d_%H:%M:%S") clicks_to_csv.sh nr_args=$# args=$@"
port_nr=""
if [ $# -eq 1 ]; then		# The port_nr
	port_nr=$1	
fi
echo "$(date +"%Y-%m-%d_%H:%M:%S") clicks_to_csv.sh port_nr: "$port_nr
 
g_base=$HOME/iapg-main

fi_conf=${g_base}/etc/iapg_server.conf
dir_stat=${g_base}/var/stat

keep_click_statistics_days=7

keep_click_statistics_days=`cat $fi_conf | grep "^[[:space:]]*keep_click_statistics_days[[:space:]]*=" | awk -F= '{print $2}' | awk '{print $1}' | tr -d '[:blank:]'`
if [[ !($keep_click_statistics_days =~ ^[0-9]+$) ]]; then
	echo "$(date +"%Y-%m-%d_%H:%M:%S") iapg_click_stats_to_csv.sh keep_click_statistics_days not a number: "$keep_click_statistics_days
	exit
fi

if [[ "$(echo ${dir_stat}/click*.json)" ==  "${dir_stat}/click*.json" ]]; then
	echo "$(date +"%Y-%m-%d_%H:%M:%S") iapg_click_stats_to_csv.sh ${dir_stat} empty. No json-files => No statistics."
	exit
fi

# Delete files.
find ${dir_stat} -type f -mtime +2 -name '*.json' -execdir rm -- '{}' \;
find ${dir_stat} -type f -mtime +${keep_click_statistics_days} -name '*.csv' -execdir rm -- '{}' \;


python3 ${g_base}/iapg_clicks_to_csv.py $port_nr
