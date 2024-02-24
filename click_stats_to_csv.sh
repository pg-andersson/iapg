#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2024 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

g_base="."  
fi_conf=${g_base}/etc/iapg.conf
dir_stat=${g_base}/var/stat

keep_click_statistics_days=7
 
dt_now=$(date +"%Y-%m-%d")

keep_click_statistics_days=`cat $fi_conf | grep "^[[:space:]]*keep_click_statistics_days[[:space:]]*=" | awk -F= '{print $2}' | awk '{print $1}' | tr -d '[:blank:]'`
if [[ !($keep_click_statistics_days =~ ^[0-9]+$) ]]; then
	echo "keep_click_statistics_days not a number: "$keep_click_statistics_days
	exit
fi
echo "keep_click_statistics_days: "$keep_click_statistics_days

if [ "$(echo ${dir_stat}/click*.json)" ==  "${dir_stat}/click*.json" ]; then
	echo "${dir_stat} empty. No json-files => No statistics."
	exit
fi

files=$(ls -1 ${dir_stat}/clicks_*.json)
for file in ${files[@]}; do
	dt_fi=$(echo $file|awk -F_ '{print $3}')
	dtdiff=$(echo $(date -d $dt_now +%s) $(date -d $dt_fi +%s) | awk '{print ($1 - $2) / 86400}')						
	if [[ "${dtdiff}" > $keep_click_statistics_days ]]; then
		echo "${dir_stat}/${file} will be deleted."
		rm -fv ${dir_stat}/${file}
	fi
done

python3 clicks_to_csv.py
