#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2024 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

g_arg=$@

g_base="."  
g_etc_dir=${g_base}/etc
g_html_dir=${g_base}/html
g_var_dir=${g_base}/var
g_log_dir=${g_var_dir}/log
g_fi_conf=${g_etc_dir}/iapg.conf
g_fi_start_list_conf=${g_base}/clublist.conf

declare -a g_args
declare -A g_base_pict_dir_used
declare -A g_port_nr_used
declare -i g_initial_port_nr=0
declare -i g_port_nr=0
declare -i g_nr_processes_to_start=0

g_base_pict_dir=""
g_legal_initial_port_range="53001, 53011 ... 53101, 53111, ... 53991"

function get_args
{
	declare -i local ix=0
	local ifs_save=""
	local line=""
	
	g_args=()
	
	if [[ ${#g_arg} == 0 ]] ; then
		if [[ "${g_run_to_validate_parameters}" == "y" ]]; then		
			echo "No parameter list of clubs to start"
		fi
		if [ -f ${g_fi_start_list_conf} ]; then
			if [[ "${g_run_to_validate_parameters}" == "y" ]]; then		
				echo "Will look for clubs to start in ${g_fi_start_list_conf}."
			fi
			ix=0
			while read line || [ -n "$line" ] ; do
				line=$(echo $line|sed 's/#.*//g' |sed 's/[[:space:]]\+/ /g' |sed 's/^[[:space:]]*//; s/[[:space:]]*$//') #Remove comments and reduce whitespace.
				if [[ "${line}" != "" ]] ; then
					g_args[${ix}]=$line
					ix=${ix}+1
				fi
			done < $g_fi_start_list_conf
			
		else
			echo "No parameter list of clubs and not any ${g_fi_start_list_conf}. Nothing to do but to exit."
			print_usage		
		fi
	else
		ix=0
		ifs_save=$IFS
		IFS=$' '
		for arg in ${g_arg[@]}; do
			g_args[${ix}]=${arg}
			ix=${ix}+1
		done
		IFS=$ifs_save
	fi
	
	if [[ ${#g_args} == 0 ]] ; then	
			echo "No parameter list of clubs and not any clubs in ${g_fi_start_list_conf}. Nothing to do but to exit."
			print_usage		
	fi
}	


function print_usage
{
	echo "Usage 1: iapg_start.sh club-dir1:number-of-tablets-club-dir1  club-dir2:number-of-tablets-club-dir2 ... "
	echo "Usage 2: The parameters can also be saved in $g_fi_start_list_conf and started by just the command:"
	echo "Usage 2: iapg_start.sh"
	echo ""
	echo "The following clubs can be started:"

	IFS=$'\n'
	dirs=$(ls ${g_html_dir} | grep "club-")
  	for dir in ${dirs[@]}; do
		g_initial_port_nr=$(echo $dir | awk -F- '{print $2}')
		if [[ $g_initial_port_nr =~ ^[0-9]+$ ]]; then
			if [[ ${g_initial_port_nr} -ge 53001 ]]&& [[ ${g_initial_port_nr} -le 53991 ]]; then
				echo $dir
			fi
		fi
	done
	exit
}


function get_port_exit_if_illegal
{
	declare -i local n=0
	local initial_port_nr_str=""
	
	initial_port_nr_str=$(echo $g_base_pict_dir  |awk -F- '{print $2}')	
	if [[ !($initial_port_nr_str =~ ^[0-9]+$) ]]; then
		echo "The club-directory: "$g_base_pict_dir" The port:"${initial_port_nr_str}" is not in the range "$g_legal_initial_port_range
		print_usage
	fi		

	g_initial_port_nr=$initial_port_nr_str
	if [[ $g_initial_port_nr < 53001 ||  $g_initial_port_nr > 53991 ]]; then
		echo "The club-directory: "$g_base_pict_dir" "${g_initial_port_nr}"  is not in the range "$g_legal_initial_port_range
		print_usage
	fi
		
	n=$(($g_initial_port_nr % 10))
	if [ $n -ne 1 ]; then
		echo $g_initial_port_nr" is not in the range "$g_legal_initial_port_range
	fi
}


function print_fixit
{
	echo "The problem must be fixed before any viewing can be started."
	exit
}


function exit_if_base_pict_dir_used_twice
{
	local d=""

	for d in ${g_base_pict_dir_used[@]}; do
		if [[ ${d} == ${g_base_pict_dir} ]]; then
			echo "The club-directory: "${g_base_pict_dir}" is used twice."
			for key in ${!g_base_pict_dir_used[@]} ; do
				echo "In use: "${key}
			done
			print_usage
		fi
	done
}


function exit_if_port_nr_used_twice
{
	local p=""

	for p in ${g_port_nr_used[@]}; do
		if [[ ${p} == ${g_port_nr} ]]; then
			echo "The port_nr "${g_port_nr}" is used twice"
			for key in ${!g_port_nr_used[@]} ; do
				echo "In use: "${key}
			done
			print_usage
		fi
	done
}

					
function start_servers
{
	# club-53001:1  
	# club-53001:3
	# club-53001:2 club-53011:2
	# club-53001:1

	declare -i local ix=0
	declare -i local n=0
	declare -i local i=0
	declare -a local valarr
	local ifs_save=""
	declare -i local wait_s_next_start=0
	
	g_base_pict_dir_used=()
	g_port_nr_used=()
	
	get_args	
	#echo "g_args?"${g_args[@]}"?"

	for arg in ${g_args[@]}; do		
		if [[ $arg != *:* ]]; then
			echo "Invalid start parameter. Must have a club-directory:number-of-tablets pair. Has '${arg}'."
			print_usage
		fi
		s1=$(echo $arg| awk -F: '{for (i=1; i<=NF; i++) print $i }' )
		ix=0
		valarr=()
		for s in ${s1[@]}; do
			valarr[$ix]=$s
			ix=${ix}+1
		done
		
		if [[ ${ix} != 2 ]] ; then
			echo "Invalid start parameter. Must have a club-directory:number-of-tablets pair. Has ${arg} but no number."
			print_usage
		fi

		g_base_pict_dir=${valarr[0]}
		nr_servers=${valarr[1]}

		dir=$(echo $g_base_pict_dir  |awk -F- '{print $1}')
		if [[ ${dir} != "club" ]]; then
			echo "Invalid start parameter. The club-directory is "${g_base_pict_dir}" but must begin with 'club-'."
			print_usage
		fi
		
		get_port_exit_if_illegal
		
		pict_dir=${g_html_dir}/${g_base_pict_dir}

		if [ ! -d ${pict_dir} ]; then
			echo "Invalid start parameter. The club-directory: "${pict_dir}" does not exist."
			print_usage
		fi	

		# Check if the directories of the club members have signature pictures.
		ifs_save=$IFS
		IFS=$'\n'
		for club_memb in $(ls -1 ${pict_dir}); do
			if [ -d ${club_memb} ]; then				
				sign_fi=${pict_dir}/${club_memb}"/"${club_memb}.jpg
				if [ ! -s ${sign_fi} ]; then
					echo "Invalid start parameter. The signature picture "${sign_fi}" is missing."
					print_fixit
				fi	
			fi
		done
		IFS=$ifs_save	
		exit_if_base_pict_dir_used_twice
		g_base_pict_dir_used["$g_base_pict_dir"]=$g_base_pict_dir								
		g_port_nr_used["$g_initial_port_nr"]=$g_initial_port_nr

		if [[ ${nr_servers} -lt 1 ]] || [[ ${nr_servers} -gt 10 ]]; then
			echo "Invalid start parameter. The club-directory is "$g_base_pict_dir" and the number of thumbnails-tablets is ${nr_servers} but must be [1-10]."
			print_usage
		fi

		ix=0
		while [ ${ix} -lt ${nr_servers} ] ; do
			g_port_nr=$g_initial_port_nr+$ix
			if [ ${ix} -gt 0 ]; then
				exit_if_port_nr_used_twice
				g_port_nr_used["$g_port_nr"]=$g_port_nr			
			fi
			ix=$ix+1	
			
			if [[ "${g_run_to_validate_parameters}" == "y" ]]; then		
				echo "The club-directory: "$g_base_pict_dir" Port: "$g_port_nr" is valid."
				g_nr_processes_to_start=$g_nr_processes_to_start+1
			fi
			if [[ "${g_run_to_validate_parameters}" == "n" ]]; then		
				suff=$(date +%Y-%m-%d_%H%M%S)
				fi_log=${g_log_dir}/server_${g_port_nr}_${suff}.log
				cmd="node iapg_server.js ${g_base_pict_dir} ${g_port_nr}> ${fi_log} 2>&1 &"	
				node iapg_server.js ${g_base_pict_dir} ${g_port_nr} > ${fi_log} 2>&1 &	
				echo $(date +"%y%m%d-%H%M%S")" Started: "${cmd}

				# Do not start all servers at the same moment.
				if [ ${ix} -lt ${nr_servers} ] ; then				
					wait_s_next_start=$(($pict_displaytime_slideshow / $g_nr_processes_to_start))
					echo $(date +"%y%m%d-%H%M%S")" Will wait "${wait_s_next_start}"s before next start."
					sleep ${wait_s_next_start}
				fi
			fi
		done
	done
}

# Check the config parameters before starting any iapg_server.
err_found=0
waittime_before_slideshow_starts=`cat $g_fi_conf | grep "^[[:space:]]*waittime_before_slideshow_starts[[:space:]]*=" | awk -F= '{print $2}' | awk '{print $1}' | tr -s '[:blank:]'`
if [[ !($waittime_before_slideshow_starts =~ ^[0-9]+$) ]]; then
	echo "waittime_before_slideshow_starts in $g_fi_conf must be a number: "$waittime_before_slideshow_starts
	err_found=1
fi
if [[ ${waittime_before_slideshow_starts} -lt 3 ]] || [[ ${waittime_before_slideshow_starts} -gt 180 ]]; then
	echo "waittime_before_slideshow_starts in $g_fi_conf is "$waittime_before_slideshow_starts" Must be [3 - 180]."
	print_fixit
fi

pict_displaytime_slideshow=10
pict_displaytime_slideshow=`cat $g_fi_conf | grep "^[[:space:]]*pict_displaytime_slideshow[[:space:]]*=" | awk -F= '{print $2}' | awk '{print $1}' | tr -s '[:blank:]'`
if [[ !($pict_displaytime_slideshow =~ ^[0-9]+$) ]]; then
	echo "pict_displaytime_slideshow in $g_fi_conf must be a number: "$pict_displaytime_slideshow
	err_found=1
fi
if [[ ${pict_displaytime_slideshow} -lt 3 ]] || [[ ${pict_displaytime_slideshow} -gt 30 ]]; then
	echo "pict_displaytime_slideshow in $g_fi_conf is "$pict_displaytime_slideshow" Must be [3 - 30]."
	print_fixit
fi

keep_click_statistics_days=`cat $g_fi_conf | grep "^[[:space:]]*keep_click_statistics_days[[:space:]]*=" | awk -F= '{print $2}' | awk '{print $1}' | tr -s '[:blank:]'`
if [[ !($keep_click_statistics_days =~ ^[0-9]+$) ]]; then
	echo "keep_click_statistics_days in $g_fi_conf must be a number: "${keep_click_statistics_days}.
	err_found=1
fi

keep_logs_days=`cat $g_fi_conf | grep "^[[:space:]]*keep_logs_days[[:space:]]*=" | awk -F= '{print $2}' | awk '{print $1}' | tr -s '[:blank:]'`
if [[ !($keep_logs_days =~ ^[0-9]+$) ]]; then
	echo "keep_logs_days in $g_fi_conf must be a number: "${keep_logs_days}.
	err_found=1
fi

if [[ ${err_found} == 1 ]]; then
	echo "Fix the parameters in $g_fi_conf and try again."
	print_fixit
fi

g_run_to_validate_parameters="y"
echo $(date +"%y%m%d-%H%M%S")" Validation of the parameters:"
start_servers

g_run_to_validate_parameters="n"
echo $(date +"%y%m%d-%H%M%S")" Validation succeeded. Starting the servers now:"
echo "Kill any yet running servers before starting new ones."
bash iapg_stop.sh		
start_servers

echo "keep_logs_days: "${keep_logs_days}.
find "${g_log_dir}" -name "*.log" -type f -mtime +${keep_logs_days} -exec rm -v {} \;
