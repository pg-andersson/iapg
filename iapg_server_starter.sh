#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later
#
# This script is started by iapg_init_server.sh. 
# It has two tasks: 
# 1) It starts the picture servers for the clubs in clublist.conf. One server per club. One port per server.
#   Tablets and kiosks use ports (in "pairs/groups") to "talk to" a picture server.
#
# 2) It restarts the picture servers when an administrator has done one of the following changes: 
# - added/deleted a picture, a member directory or a club directory 
# - updated clublist.conf
# It checks the modified time stamps every 10th second and restarts the affected picture servers when a time stamp has changed.
 
g_bash=$(which "bash")

g_base=$HOME/iapg-main
g_etc_dir=${g_base}/etc
g_html_dir=${g_base}/html
g_var_dir=${g_base}/var
g_log_dir=${g_var_dir}/log
g_stat_dir=${g_var_dir}/stat

g_fi_server_conf=${g_etc_dir}/iapg_server.conf
g_fi_clublist=${g_etc_dir}/clublist.conf
g_fi_kiosk_conf=${g_etc_dir}/iapg_kiosk.conf
suff=$(date +%Y-%m-%d_%H-%M-%S)
g_fi_log=${g_log_dir}"/iapg_server_starter_"${suff}".log"
g_fi_active_servers=${g_log_dir}"/active_servers"
g_fi_active_servers_pid=${g_log_dir}"/active_servers_pid"
g_fi_server_dir_tree=${g_log_dir}"/a_server_dir_tree.txt"

echo $g_bash >> $g_fi_log
echo "base_dir="${g_base} >> $g_fi_log

source ${g_base}/iapg_functions.sh

declare -a g_clublist
declare -A g_clublist_dirs
declare -A g_ts_clubdirs
declare -A g_active_clubdirs
declare -A g_port_nr_used
declare -i g_initial_port_nr=0
declare -i g_port_nr=0

g_deb_func_call=0

g_keep_logs_days=7
g_keep_click_statistics_days=7
g_pict_displaytime_slideshow=10
g_waittime_before_slideshow_starts=60
g_show_kiosk_ip_as_footer=0

g_status_server_type="picture_server"
g_status_server_port_nr=53000
				
g_club_dir=""
g_legal_initial_port_range="53001, 53011, 53021, ... 53101, 53111, ... 53991"

declare -i g_restart_all_servers=1

function log_deb()
{
	log_line=$@
	local dt
	
	if [[ ${g_deb_func_call} == 1 ]]; then
		dt=$(date +"%Y-%m-%d_%H:%M:%S")
		echo "${dt} ${log_line}" >> $g_fi_log		
	fi
}


function is_base_pict_dir_unique()
{
	local d=""

	for d in ${g_clublist_dirs[@]}; do
		if [[ ${d} == ${g_club_dir} ]]; then
			log_user_err "The club-directory: "${g_club_dir}" is used twice." 
			for key in ${!g_clublist_dirs[@]} ; do
				log_user_err "In use: "${key}
			done
			log_user_err "The system will wait to start until the duplicate club directories in the parameters for the club directories are gone." 
			return 0
		fi
	done
	return 1
}


function is_placement_order_valid()
{	
	if [[ ${g_placement_order} != "r" ]] && [[ ${g_placement_order} != "n" ]]; then
		log_user_err "The order of the members placement on the table must be: r/n"
		log_user_err "The system will wait to start until the order is proper." 
		return 0
	fi
	return 1
}


function is_port_nr_unique()
{
	local p=""

	for p in ${g_port_nr_used[@]}; do
		if [[ ${p} == ${g_port_nr} ]]; then
			log_user_err "The port_nr "${g_port_nr}" is used twice" 
			for key in ${!g_port_nr_used[@]} ; do
				log_user_err "In use: "${key}
			done
			log_user_err "The system will wait to start until the duplicate port numbers in the parameters for the club directories are gone." 
			return 0
		fi
	done
	return 1
}


function is_clublist_proper()
{
	declare -i local ix=0
	declare -i local ix1=0
	declare -i local in_club=0
	local line=""
	local ifs_save2=""

	g_clublist_dirs=()
	g_port_nr_used=()	
	g_clublist=()

	logit "is_clublist_proper: verifying."
	
	ix=0
	while read -r line ; do
		s=$(echo ${line}|sed 's/#.*//g' |sed 's/[[:space:]]\+/ /g' |sed 's/^[[:space:]]*//; s/[[:space:]]*$//') #Remove comments and reduce whitespace.
		if [[ "${s}" == "" ]] ; then
			continue
		fi

		if [[ ${s} == "club:" ]]; then
			if [[ ${in_club} -eq 1 ]]; then
				log_user_err "Invalid club parameter. A new club: entry starts before the previous one was proper.\nThe system will wait to start." 
				return 0			
			fi
			logit "is_clublist_proper: club entry starts"
			in_club=1
			g_club_dir=""
			name=""
			nr_displays=""
			memb_pos=""
			continue
		fi
		
		if [[ ${in_club} -eq 1 ]]; then
			if [[ ${s} =~ "club_id:" ]]; then
				g_club_dir=$(echo $s | awk -F: '{print $2}' | sed 's/[[:space:]]*//g' )
				nr=$(echo $g_club_dir | awk -Fclub- '{print $2}')
				if [[ !( $nr =~ ^[0-9]{1,2} ) ]]; then
					log_user_err "Invalid club parameter. The club_id: $g_club_dir is not in the range $g_legal_club_range.\nThe system will wait to start." 
					return 0
				fi	
				
				pict_dir=${g_html_dir}/${g_club_dir}
				if [ ! -d ${pict_dir} ]; then
					log_user_err "Invalid club parameter. The club-directory: "${pict_dir}" does not exist.\nThe system will wait to start." 
					return 0
				fi	
				
				is_base_pict_dir_unique
				iret=$?
				if [[ ${iret} -eq 0 ]]; then
					return 0
				fi
				g_clublist_dirs["$g_club_dir"]=$g_club_dir								

				# Check if the directories of the club members have signature pictures.
				ifs_save2=$IFS
				IFS=$'\n'
				for club_memb in $(ls -1 ${pict_dir}); do
					if [ -d ${club_memb} ]; then				
						sign_fi=${pict_dir}/${club_memb}"/"${club_memb}.jpg
						if [ ! -s ${sign_fi} ]; then
							log_user_err "Invalid club parameter. The signature picture "${sign_fi}" is missing.\nThe system will wait to start." 
							IFS=$ifs_save2	
							return 0
						fi	
					fi
				done
				IFS=$ifs_save2	
				
				continue
			fi
			
			if [[ ${s} =~ "club_name:" ]]; then
				s1=$(echo $s | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')	
				if [[ ${s1} == "" ]]; then
					s1="anonymous"
				fi
				maxlen=${#s1}
				if [[ $maxlen -gt 30 ]]; then
					maxlen=30
				fi				
				name=${s1:0:maxlen}
				continue
			fi
			
			if [[ ${s} =~ "nr_of_displays:" ]]; then
				nr_displays=$(echo $s | awk -F: '{print $2}' | sed 's/[[:space:]]*//g')		
				if [[ ${nr_displays} -lt 1 ]] || [[ ${nr_displays} -gt 10 ]]; then
					log_user_err "Invalid club parameter. The club-directory is "$g_club_dir" and the number of thumbnails-tablets is ${nr_displays} but must be [1-10].\nThe system will wait to start." 
					return 0
				fi
				continue
			fi
			
			if [[ ${s} =~ "member_position:" ]]; then
				memb_pos=$(echo $s | awk -F: '{print $2}' | sed 's/[[:space:]]*//g')					
				if [[ ${memb_pos} != "r" ]] && [[ ${memb_pos} != "n" ]]; then
					log_user_err "Invalid club parameter. The member-position: must be: r/n. \nThe system will wait to start until the order is proper." 
					return 0
				fi			

				if [[ ${g_club_dir} == "" || ${name} == "" || ${nr_displays} = "" || ${memb_pos} == "" ]]; then
					log_user_err  "Invalid club parameter. All 4 fields must be used (not empty).\nThe system will wait to start."
					return 0
				fi
				
				line_trimmed=${g_club_dir}":"${nr_displays}":"${memb_pos}":"${name}		
				g_clublist[${ix}]=${line_trimmed}
				logit "ok: ${g_clublist[${ix}]}"				
				ix=${ix}+1
				
				in_club=0
			fi
		fi		
	done < $g_fi_clublist
	
	if [[ ${#g_clublist} -eq 0 ]] ; then	
		log_user_err "No clubs in $g_fi_clublist.\nThe system will wait until there is a club to start."
		return 0
	fi
	
	logit "is_clublist_proper is ok."
	return 1	
}


function is_something_modified()
{	
	local diff
	if [ -f ${g_fi_server_conf} ]; then
		g_ts_conf=$(date -r ${g_fi_server_conf} +%s)
		diff=$(($g_ts_conf - $g_last_ts_conf))
		if [[ ${diff} -gt 0 ]]; then
			return 1
		fi
	fi
}


function get_iapg_server_config_if_proper()
{
	logit "get_iapg_server_config_if_proper: verifying."	

	if [ ! -f ${g_fi_server_conf} ]; then
		log_user_err "Fix the config ${g_fi_server_conf}. It is missing" 
		return 0
	fi

	err_found=0
	while read -r line ; do
		trimmed_line=$(echo ${line}|sed 's/#.*//g' |sed 's/[[:space:]]\+//g' ) #Remove comments and whitespace.
		if [[ "${trimmed_line}" != "" ]] ; then
			if [[ "${trimmed_line}" =~ "waittime_before_slideshow_starts" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				if ! [[ $s =~ ^[0-9]+$ ]]; then
					log_user_err "waittime_before_slideshow_starts in $g_fi_server_conf is $s but must be a number[3 - 180] 1." 
					err_found=1
				else
					g_waittime_before_slideshow_starts=$s
					if [[ ${g_waittime_before_slideshow_starts} -lt 3 ]] || [[ ${g_waittime_before_slideshow_starts} -gt 180 ]]; then
						log_user_err "waittime_before_slideshow_starts in $g_fi_server_conf is $g_waittime_before_slideshow_starts but must be [3 - 180] 2." 
						err_found=1
					fi
				fi
			fi	

			if [[ "${trimmed_line}" =~ "pict_displaytime_slideshow" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')	
				if ! [[ $s =~ ^[0-9]+$ ]]; then
					log_user_err "pict_displaytime_slideshow in $g_fi_server_conf is $s but must be [3 - 30]." 
					err_found=1
				else
					g_pict_displaytime_slideshow=$s
					if [[ ${g_pict_displaytime_slideshow} -lt 3 ]] || [[ ${g_pict_displaytime_slideshow} -gt 30 ]]; then
						log_user_err "pict_displaytime_slideshow in $g_fi_server_conf is $g_pict_displaytime_slideshow but must be [3 - 30]." 
						err_found=1
					fi
				fi
			fi

			if [[ "${trimmed_line}" =~ "keep_click_statistics_days" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				if ! [[ $s =~ ^[0-9]+$ ]]; then
					log_user_err "keep_click_statistics_days in $g_fi_server_conf is ${s} but must be a number." 
					err_found=1
				fi
				g_keep_click_statistics_days=$s
			fi
			
			if [[ "${trimmed_line}" =~ "keep_logs_days" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				if ! [[ $s =~ ^[0-9]+$ ]]; then
					log_user_err "keep_logs_days in $g_fi_server_conf is ${s} but must be a number."  
					err_found=1
				fi				
				g_keep_logs_days=$s
			fi	
			if [[ "${trimmed_line}" =~ "show_kiosk_ip_as_footer" ]] ; then
				s=$(echo $trimmed_line | awk -F= '{print $2}')
				if ! [[ $s =~ ^[0-1]+$ ]]; then
					log_user_err "show_kiosk_ip_as_footer in $g_fi_server_conf is ${s} but must be 0/1."  
					err_found=1
				fi				
				g_show_kiosk_ip_as_footer=$s
			fi		
			
		fi
	done < $g_fi_server_conf

	if [[ ${err_found} -eq 1 ]]; then
		log_user_err "The system will wait to start until the errors in $g_fi_server_conf are gone." 
		return 0
	fi
	logit "get_iapg_server_config_if_proper: is ok."	
	return 1
}


function purge_club_name_files()
{
	rm -v ${g_var_dir}/*_club_name.txt >> $g_fi_log 2>&1
}


function start_server()
{
	declare -i local ix=0
	declare -i local wait_before_next_start=0

	while [ ${ix} -lt ${g_nr_servers} ] ; do
		g_port_nr=$g_initial_port_nr+$ix
		ix=$ix+1	
				
		suff=$(date +%Y-%m-%d_%H-%M-%S)
		fi_log_server=${g_log_dir}/iapg_server_${g_port_nr}_stdout_err_${suff}.log
		cmd="node ${g_base}/iapg_server.js ${g_club_dir} ${g_port_nr} ${g_placement_order} > ${fi_log_server}"	
		
		if [[ ${g_placement_order} == "r" ]] ; then
			sortorder="Photographers are in random order"
		else
			sortorder="Photographers are in name order"
		fi
		g_started_clubs+="${g_club_dir} Tablet-Kiosk-group: ${ix}, Tablet(s) and kiosk(s) connect to port: ${g_port_nr}, ${g_club_name}, ${sortorder} #"
		g_started_clubs_short+="${g_club_dir}:${g_port_nr}#"
		logit "start_server: To be started: ${cmd}"
		node ${g_base}/iapg_server.js ${g_club_dir} ${g_port_nr} ${g_placement_order}  > ${fi_log_server} 2>&1 &	

		# Do not start all servers at the same moment.
		if [[ ${ix} -lt ${g_nr_servers} ]] ; then				
			wait_before_next_start=2
			logit "start_server: Will wait "${wait_before_next_start}"s before next start." 
			sleep ${wait_before_next_start}
		fi
	done
}			

				
function start_servers()
{
	# club-53001:1:r:a name 

	declare -i local nr_club=0
	declare -i local ix=0
	declare -i local n=0
	declare -i local i=0
	declare -a local club_fields
	local club=""
	local ifs_save1
	
	purge_club_name_files

	if [[ ${g_restart_all_servers} -eq 1 ]]; then
		logit "start_servers: Will now run iapg_stop.sh to kill all running picture servers." 
		$g_bash ${g_base}/iapg_stop.sh	"stop_all_servers" >> $g_fi_log	
	else	
		logit "start_servers: Will now run iapg_stop.sh to kill servers supporting the just updated picture directory ${g_servers_to_restart}." 
		$g_bash ${g_base}/iapg_stop.sh	${g_servers_to_restart} >> $g_fi_log	
	fi
		
	g_started_clubs="#"
	g_started_clubs_short=""


	nr_club=${#g_clublist[*]}
	ix=0
	while [ $ix -lt $nr_club ] 
	do
		club=${g_clublist[${ix}]}
		ix=$ix+1
		

		ifs_save1=$IFS
		IFS=':'
		read -ra club_fields <<< "$club"
		IFS=$ifs_save1
	
		g_club_dir=${club_fields[0]}
		g_nr_servers=${club_fields[1]}
		g_placement_order=${club_fields[2]}
		g_club_name=${club_fields[3]}
		
		if [[ ${g_restart_all_servers} -eq 1 ]]; then
			logit "start_servers: for club: $g_club_dir $g_club_name nr_servers=$g_nr_servers tablet_member_pos=$g_placement_order"
		fi
		
		# Put the name of the club in a file. /home/fg/iapg-main/var/club-1_club_name.txt
		fi_club_name=${g_var_dir}/${g_club_dir}_club_name.txt
		echo ${g_club_name} > $fi_club_name		
		
		nr=$(echo $g_club_dir | awk -Fclub- '{print $2}')
		g_initial_port_nr=$(( 53001 + (${nr} -1)*10 ))
			
		if [[ ${g_restart_all_servers} -eq 0 ]]; then
			if [[ ${g_servers_to_restart} == ${g_club_dir} ]]; then
				logit "start_servers: for club: $g_club_dir $g_club_name nr_servers=$g_nr_servers tablet_member_pos=$g_placement_order"
				start_server
				return
			fi
		else
			start_server
		fi		
	done
	
	dt=$(date +"%Y-%m-%d_%H:%M:%S")
	echo "${dt} ${g_started_clubs}" > $fi_info_started_clubs
	echo "${g_started_clubs_short}" > $fi_started_clubs

	logit "start_servers: keep_logs_days: "${g_keep_logs_days}. 
	find "${g_log_dir}" -name "*.log" -type f -mtime ${g_keep_logs_days} -exec rm -v {} \;
	logit "start_servers: Done now"
	log_run_status_logit "All club servers are started"
}


function is_clublist_modified()
{	
	local diff
	if [ -f ${g_fi_clublist} ]; then
		g_ts_clublist=$(date -r ${g_fi_clublist} +%s)
		diff=$(($g_ts_clublist - $g_last_ts_clublist))
		if [[ ${diff} -gt 0 ]]; then
			return 1
		fi
	fi
}


function is_server_conf_modified()
{	
	local diff
	if [ -f ${g_fi_server_conf} ]; then
		g_ts_conf=$(date -r ${g_fi_server_conf} +%s)
		diff=$(($g_ts_conf - $g_last_ts_conf))
		if [[ ${diff} -gt 0 ]]; then
			return 1
		fi
	fi
}


function get_active_clubdirs()
{
	local ifs_save1=""
	declare -a local subdir
	
	dirs=$(find ${g_html_dir} -type	d)
	while read -r tmp_dir; do
		ifs_save1=$IFS
		IFS='/'
		read -ra subdir <<< "$tmp_dir"
		IFS=$ifs_save1
			if [[ ${#subdir[@]} -gt 4 ]] ; then
				if [[ ${subdir["5"]} =~ "club" ]]; then
					club=${subdir["5"]}				
					if [[ -z ${g_active_clubdirs[$club]}  ]] ; then							
						if [[ ! -z ${g_clublist_dirs[$club]} ]]; then	
							g_active_clubdirs[$club]=${tmp_dir}			# 					
						fi
					fi
				fi
			fi						
			
	done <<< $dirs	
}


function wait_until_memberdir_size_is_stable()
{	
	
	log_deb "wait_until_memberdir_size_is_stable"
	local size_diff	
	declare -i local try_again=1
	
	prev_member_dir_size=$(du -bs ${g_member_dir} | awk '{print $1}' )
	while [ ${try_again} -gt 0 ]; do
		ts=$(date +"%s")
		logit "is_any_memberdir_modified: ts=$ts ${g_member_dir}. Wait 2 s before testing if the picture transfer has completed."
		sleep 2

		ts=$(date +"%s")
		logit "wait_until_memberdir_size_is_stable: ts=$ts ${g_member_dir} waited 2s.  size-now:${current_member_dir_size} size_prev:${prev_member_dir_size}"	
		current_member_dir_size=$(du -bs ${g_member_dir} | awk '{print $1}' )		
		if [[ ${current_member_dir_size} == "" ]]; then
			if [ ${try_again} -ge 3 ]; then
				logit "wait_until_memberdir_size_is_stable: ts=$ts ${g_member_dir} The directory has disappeared. try_again=${try_again} Leave it "	
				return
			fi
			logit "wait_until_memberdir_size_is_stable: ts=$ts ${g_member_dir} The directory has disappeared. try_again=${try_again} "	
			try_again=$try_again+1			
		fi
		
		size_diff=$(($current_member_dir_size - $prev_member_dir_size))
		if [[ ${size_diff} -ne 0 ]]; then
			prev_member_dir_size=${current_member_dir_size}
			ts=$(date +"%s")
			logit "wait_until_memberdir_size_is_stable: ts=$ts ${g_member_dir} size-diff: ${size_diff} != 0 => The transfer can still be active."	
		else
			g_ts_member_dir=$(stat -c %Y ${g_member_dir})
			ts=$(date +"%s")
			log_deb "wait_until_memberdir_size_is_stable: ts=$ts ${g_member_dir} size-diff: = 0 => dir-size is stable. Regard the transfer as completed."
			return
		fi
	done
}

	
function is_any_memberdir_modified()
{	
	log_deb "is_any_memberdir_modified"
	# Return as soon as a modified member dir is found. It is enough to find one modified memberdir in a clubdir
	local ts_diff
	local ifs_save1=""

	ifs_save1=$IFS
	IFS=$'\n'	
	
	member_dirs=$(find ${g_clubdir} -type	d)
	while read -r g_member_dir; do
		# Look for a modified member dir.
		# if g_member_dir == /home/fg/iapg-main/html/club-2   Bypass it. It is only clubdir and not a member dir.
		ifs_save1=$IFS
		IFS='/'
		read -ra subdir <<< "${g_member_dir}"
		IFS=$ifs_save1
		if [[ ${#subdir[@]} -eq 6 ]] ; then
			#logit "${subdir[5]} Bypass this empty: clubdir"
			continue
		fi

		ts_member_dir=$(stat -c %Y ${g_member_dir})		
		ts_diff=$(($ts_member_dir - $g_last_ts_club_dir))

		ts=$(date +"%s")
		#logit "${g_member_dir} $ts ts_member_dir:$ts_member_dir g_last_ts_club_dir:$g_last_ts_club_dir" 
				
		if [[ ${ts_diff} -gt 0 ]]; then
			wait_until_memberdir_size_is_stable
			IFS=$ifs_save1	
			return 1
		fi
	done <<< $member_dirs	
	IFS=$ifs_save1	
}


function is_clubdir_modified()
{	
	log_deb "is_clubdir_modified"
	local ts_diff
	
	ts_club_dir=$(stat -c %Y ${g_clubdir})				
	ts_diff=$(($ts_club_dir - $g_last_ts_club_dir))		
		
	if [[ ${ts_diff} -gt 0 ]]; then
		ts=$(date +"%s")
		g_ts_clubdirs["$club"]=$ts	
		g_servers_to_restart=$club
		logit "is_clubdir_modified: ts=$ts ${g_clubdir} has changed. A memberdir must have been deleted."
		return 1
	fi
}


function is_any_clubdir_modified()
{	
	log_deb "is_any_clubdir_modified"
	# Return as soon as a modified memberdir or clubdir is found. 
	
	get_active_clubdirs
	for club in ${!g_active_clubdirs[@]}; do
		g_clubdir=${g_active_clubdirs[${club}]}
		
		if [[ ${g_ts_clubdirs["$club"]} == "" ]]; then
			logit "is_any_clubdir_modified: New ${club} added"
			ts=$(date +"%s")
			g_ts_clubdirs["$club"]=$(($ts - 19))	# New club. Checked every 10s. Set the timestamp back enough so a change since the previous check will not be missed.
		fi
		
		g_last_ts_club_dir=${g_ts_clubdirs["$club"]}
		
		is_any_memberdir_modified		
		iret=$?
		if [[ ${iret} -eq 1 ]]; then
			ts=$(date +"%s")
			g_ts_clubdirs["$club"]=$(($ts - 2))		# Adjust for the final 2s wait in the loop above.
			g_servers_to_restart=$club
			return 1
		fi	

		# No memberdirs have been added or updated. Check if the clubdir itself has been modified (because of a delete of a memberdir).   
		is_clubdir_modified		
		iret=$?
		if [[ ${iret} -eq 1 ]]; then
			return 1
		fi

		done
}


function is_something_modified()
{
	declare -i local modif=0
	log_deb "is_something_modified:"

	g_restart_all_servers=0	
	is_clublist_modified
	iret=$?
	if [[ ${iret} -eq 1 ]]; then
		ts=$(date +"%s")
		logit "is_something_modified: ts=$ts ${g_fi_clublist} has been modified. Restart all servers."
		g_last_ts_clublist=$g_ts_clublist
		g_restart_all_servers=1	
		modif=1
	fi

	is_server_conf_modified
	iret=$?
	if [[ ${iret} -eq 1 ]]; then
		ts=$(date +"%s")
		logit "is_something_modified: ts=$ts ${g_fi_server_conf} has been modified. Restart all servers."
		g_last_ts_conf=$g_ts_conf
		g_restart_all_servers=1
		modif=1
	fi
	
	is_any_clubdir_modified
	iret=$?
	if [[ ${iret} -eq 1 ]]; then
		ts=$(date +"%s")
		logit "is_something_modified: ts=$ts ${g_html_dir} picture transfer completed. Restart some servers."
		g_last_ts_html_dir=$g_ts_html_dir
		modif=1
	fi

	if [[ ${modif} -eq 1 ]]; then
		sleep 1		# Not likely but the configs might not be fully transferred yet.
		return 1
	fi
	
	return 0
}


function update_server_run_status()
{
	log_deb "update_server_run_status"
	ps -ax|grep iapg_server.js | grep -v grep | awk '{print $7"_"$8}' > ${g_fi_active_servers}		
	ps -aux|grep iapg_server.js | grep -v grep > ${g_fi_active_servers_pid}				
}


function wait_until_proper_configs()
{
	declare -i local loop_nr=0
	declare -i local try_now=1
	declare -i local clublist_proper=0
	declare -i local config_proper=0

	if [ -f ${fi_config_status_ok} ]; then
		echo ""  > $fi_config_status_ok
	fi
	if [ -f ${fi_config_error} ]; then
		rm $fi_config_error
	fi
				
	log_run_status_logit "wait_until_proper_configs: Waiting for all configs to be properly updated."
	
	while [ 1 -eq 1 ]
	do
		loop_nr=$loop_nr+1
		n=$((loop_nr % ${log_modif_check_counter}))
		if [[ ${n} -eq 0 ]]; then
			log_run_status_logit "wait_until_proper_configs loop_nr=${loop_nr} clublist_proper=${clublist_proper} config_proper=${config_proper}."
		fi
		
		if [[ ${try_now} -eq 1 ]]; then
			log_user_err "Validates configuration." 
			is_clublist_proper			
			clublist_proper=$?
			
			get_iapg_server_config_if_proper
			config_proper=$?

			if [[ ${config_proper} -eq 1 ]]; then
				echo "${g_fi_server_conf} seems proper."  >> $fi_config_status_ok
			fi
			
			if [[ ${clublist_proper} -eq 1  ]]; then
				echo "${g_fi_clublist} seems proper."  >> $fi_config_status_ok
			fi
						
			if [[ ${clublist_proper} -eq 1 && ${config_proper} -eq 1 ]]; then
				if [ -f ${fi_config_error} ]; then
					rm $fi_config_error
				fi
				log_run_status_logit "wait_until_proper_configs: The parameter files are proper."
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


function start_status_server()
{
	suff=$(date +%Y-%m-%d_%H-%M-%S)
	fi_log_server=${g_log_dir}/iapg_status_server_stdout_err_${suff}.log
	cmd="node ${g_base}/iapg_status_server.js ${g_status_server_port_nr} ${g_status_server_type} > ${fi_log_server}"	
	logit "start_status_server: To be started: ${cmd}"
	node ${g_base}/iapg_status_server.js  ${g_status_server_port_nr} ${g_status_server_type}  > ${fi_log_server} 2>&1 &	
}			


function log_tree()
{
	tree ${g_base} -I "node_mod*|*csv|*json|*a*.txt|*_club-*|active_serv*|iapg*.log" --dirsfirst  > ${g_fi_server_dir_tree}		
}


function wait_for_network_to_be_up()
{
	declare -i local loop=1
	declare -i local nr_sec=0
	local dt
	local s
	declare -i local reboot_when_network_not_up_after=86400  # A day

	reboot_when_network_not_up_after=$1	

	log_run_status_logit "wait_for_network_to_be_up: The system will be booted again after an ongoing boot if the network is still not up after ${reboot_when_network_not_up_after} seconds." 
	
	# Loop until the network is up and the system has got an address.				
	while [ 1 -eq 1 ]
	do
		if_up=$(ip a | grep -v 127.0 | grep "inet " | grep -v "::1/128")

		if [[ "${if_up}" == *"inet "* ]]; then
			log_run_status_logit "wait_for_network_to_be_up: Link is up and the system has an address ${loop} trials" 
			return
		fi
		
		if [ $((loop % 10)) -eq 0 ]; then
			log_run_status_logit "wait_for_network_to_be_up: Still not any link up. Trial nr=${loop}" 
		fi
		
		loop=${loop}+1
		sleep 5
		nr_sec=${nr_sec}+5
		if [[ ${nr_sec} -gt ${reboot_when_network_not_up_after} ]]; then
			s="Still not any link up after ${nr_sec} s."
			dt=$(date +"%Y-%m-%d_%H:%M:%S")
			echo "${dt} wait_for_network_to_be_up: ${s} Request to reboot now." >> $g_fi_kiosk_reboot_log
			echo "${dt} wait_for_network_to_be_up: Request to reboot now" > $g_fi_request_kiosk_reboot		
		fi
	done
}


function restart_servers_if_the_router_recycles()
{
	ping_res=$(${g_ping} -n -c2 ${g_addr_router})
	ping_succ=$(echo ${ping_res} | grep "2 received")
	
	g_restart_all_servers=1
	if [[ ${ping_succ} == "" ]]; then
		if [[ ${g_router_down_nr} -eq 0 ]]; then
			log_run_status_logit "restart_servers_if_the_router_recycles: The router ${g_addr_router} does not respond to ping. The servers must be restarted to get in sync with the kiosks."
			start_servers			
		fi
		g_router_down_nr=$g_router_down_nr+1
	else
		# Router up
		if [[ ${g_router_down_nr} -gt 0 ]]; then
			# The router has been down and is now up again.
			log_run_status_logit "restart_servers_if_the_router_recycles: The router ${g_addr_router} is up again after ${g_router_down_nr} tests. The servers must now be restarted to get in sync with the kiosks."
			start_servers			
			g_router_down_nr=0	
		fi		
	fi
}	

#######################################
logit "Started."
declare -i log_modif_check_counter=360

#Delete files meant for a kiosk in the etc dir.
if [ -f ${g_fi_kiosk_conf} ]; then
	rm ${g_fi_kiosk_conf}
fi

# Delete obsolete status files.
find  ${g_log_dir} -type f -name "actions_server_*" -exec rm {} \;

# Delete statistics
find $g_stat_dir -mtime +${g_keep_click_statistics_days} -type f -exec rm {} \;

# Do not start servers until the system is fully is up.
wait_for_network_to_be_up 36000

g_addr_router=$(/sbin/ip route | grep -m1 "default" | awk '{ print $3 }' )

start_status_server

wait_for_router_to_be_up
	
wait_for_config_file $g_fi_server_conf
g_last_ts_conf=$(date -r ${g_fi_server_conf} +%s) 	# This time stamp will work to see if the config has been updated later on. 

wait_for_config_file ${g_fi_clublist}
g_last_ts_clublist=$(date -r ${g_fi_clublist} +%s)
g_last_ts_html_dir=$(date +%s)	

wait_until_proper_configs

log_tree

start_servers

logit "Eternal check for modified config files. Restarts servers if modified."
declare -i g_router_down_nr=0
declare -i loop_nr=0
while [ 1 -eq 1 ]
do
	loop_nr=$loop_nr+1
	n=$((loop_nr % ${log_modif_check_counter}))
	if [[ ${n} -eq 0 ]]; then
		logit "is_something_modified check counter : ${loop_nr}."
	fi
		
	update_server_run_status

	restart_servers_if_the_router_recycles

	is_something_modified	
	iret=$?
	if [[ ${iret} -eq 1 ]]; then
		wait_until_proper_configs
		log_tree
		start_servers
	fi
	
	sleep 10
done	

