#!/usr/bin/python3
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

# This program is run by click_stats_to_csv.sh. It converts the click statistics saved in json files by the picture server to csv files.
 
import sys
import platform
import os
import glob
import json
from pathlib import Path
from datetime import datetime

g_base = os.getenv("HOME") + "/iapg-main"     #debian/ubuntu
			
g_var_dir = g_base + "/var"
g_stat_dir = g_var_dir + "/stat"
g_fi_server_conf = g_base + "/etc/iapg_server.conf"

g_detailed_logging = 1


def get_dates_for_clicks_per_day_and_tablet(port_nr) :
	files = []
	for fi in glob.glob(g_stat_dir+"/*_clicks_"+port_nr+"*.json") : 
		fi_pref = fi.split("_clicks")[0]
		f_parts = fi_pref.split("/")
		fi_dt = f_parts[len(f_parts) -1]
		if fi_dt not in files :
			files.append(fi_dt)
	return(files)

	
def is_port_nr_valid() :
	print(sys.argv)
	port_nr_tmp = ""
	if len(sys.argv) == 2:	
		port_nr_tmp = str(sys.argv[1])
		if port_nr_tmp.isdigit() :
			if (int(port_nr_tmp) > 53000) and (int(port_nr_tmp) < 54000) :
				return(True, port_nr_tmp)
	else :
		print("Parameter for port_nr is missing.")

	print("Not a valid port_nr: "+port_nr_tmp )
	return(False, "")
	

def read_config_file():
	conf_params = {} 	# The param and its value.
	ret_stat = "ok"
	split_on = "="
	
	filepath = Path(g_fi_server_conf)
	if filepath.is_file():	
		f = open(g_fi_server_conf, "r", encoding="utf8")
		for rec in f:
			rec = rec.strip()
			if rec == "":
				continue
				
			if rec.find("#", 0 , 1) == 0:
				continue
					
			if rec.find("#") >-1:              # Clean the rec from any comment at the end.
				rec1 = rec.split("#")
				rec = rec1[0]						

			rec = rec.strip()			
			buf = rec.split(split_on, 1)
			par = buf[0].strip()
			if len(buf) == 2 :
				val = buf[1].strip()
				conf_params.update({par: val})			
			
		f.close()
	else:
		ret_stat = g_fi_server_conf + " Not found"
		
	return(ret_stat, conf_params)


def clicks_per_day_and_tablet_to_one(fi_dt, port_nr) :
	if g_detailed_logging == 1: 
		print("clicks_per_day_and_tablet_to_one", fi_dt)
	recs = []
	click_summary = {}
	for fi in glob.glob(g_stat_dir+"/*_clicks_"+port_nr+"*.json") : 
		fi_pref = fi.split("_clicks")[0]
		f_parts = fi_pref.split("/")
		this_fi_dt = f_parts[len(f_parts) -1]
		if this_fi_dt != fi_dt :
			continue
		
		fi_csv = fi_pref+"_click_summary.csv"
		if g_detailed_logging == 1: 
			print(fi)
		
		if os.path.getsize(fi) == 0 :
			print("Empty file:", fi)
			os.remove(fi)				
			continue
		
		f = open(fi, 'r' , encoding="utf8")
		clicks_stat = json.load(f)
		f.close()
		for member_pict in clicks_stat.keys() :
			nr_userclicks = clicks_stat[member_pict]["nr_userclicks"]				
			nr_slideshows = clicks_stat[member_pict]["nr_slideshows"]				
			if member_pict in click_summary :
				click_summary[member_pict]["nr_userclicks"] = click_summary[member_pict]["nr_userclicks"] + nr_userclicks
				click_summary[member_pict]["nr_slideshows"] = click_summary[member_pict]["nr_slideshows"] + nr_slideshows			
			else:
				click_summary[member_pict] = {}
				click_summary[member_pict]["nr_userclicks"] = nr_userclicks
				click_summary[member_pict]["nr_slideshows"] = nr_slideshows
				
	if len(click_summary) == 0 :
		return()
		
	for member_pict in click_summary:
		mp = member_pict.split("/")
		member = mp[0]
		pict = mp[1]
		rec = member +";" + pict + ";" + str(click_summary[member_pict]["nr_userclicks"]) + ";" + str(click_summary[member_pict]["nr_slideshows"]) + "\n"
		recs.append(rec)
		recs.sort()
		
	f = open(fi_csv, 'w' , encoding="utf8")
	if g_detailed_logging == 1: 
		print()
		print(fi_csv)
	f.write("member;picture;thumbnails;slideshows\n")
	for rec in recs :
		f.write(rec)
	f.close()
		

def clicks_per_day_and_tablet(port_nr) :
	if g_detailed_logging == 1: 
		print("clicks_per_day_and_tablet")
	for fi in glob.glob(g_stat_dir+"/*_clicks_"+port_nr+"*.json") : 
		fi_pref = fi.split(".json")[0]
		fi_csv = fi_pref+".csv"
		if g_detailed_logging == 1: 
			print(fi+" => "+ fi_csv)

		if os.path.getsize(fi) == 0 :
			print("Empty file:", fi)
			os.remove(fi)				
			continue
			
		f = open(fi, 'r' , encoding="utf8")
		clicks_stat = json.load(f)
		f.close()
		f = open(fi_csv, 'w' , encoding="utf8")
		f.write("member;picture;thumbnails;slideshows\n")
		recs = []
		for member_pict in clicks_stat.keys() :
			val = []
			mp = member_pict.split("/")
			member = mp[0]
			pict = mp[1]
			for v in clicks_stat[member_pict].values() :
				val.append(v)
			
			rec = member +";" + pict + ";" + str(val[0]) + ";" + str(val[1]) + "\n"
			recs.append(rec)
		
		recs.sort()
		for rec in recs :
			f.write(rec)
		f.close()
			
			
def clicks_per_run_and_tablet(port_nr) :
	if g_detailed_logging == 1: 
		print("clicks_per_run_and_tablet")
	for fi in glob.glob(g_stat_dir+"/clicks_"+port_nr+"*.json") : 
		fi_pref = fi.split(".json")[0]
		fi_csv = fi_pref+".csv"	
		if g_detailed_logging == 1: 
			print(fi+" => "+ fi_csv)

		if os.path.getsize(fi) == 0 :
			print("Empty file:", fi)
			continue
				
		f = open(fi, 'r' , encoding="utf8")
		clicks_stat = json.load(f)
		f.close()
		f = open(fi_csv, 'w' , encoding="utf8")
		f.write("member;picture;thumbnails;thumb_first;thumb_last;slideshows;slide_first;slide_last\n")
		for member in clicks_stat.keys() :
			i = 0
			for pict_info in clicks_stat[member]["picts_info"] :
				if (i == 0) : 	# Bypass the initial member picture.
					i = i + 1
					continue
					
				rec = member + ";" + \
				pict_info["pict"] + ";" + \
				str(pict_info["nr_userclicks"]) + ";" + 	\
				pict_info["first_userclick"] + ";" +		\
				pict_info["last_userclick"] + ";" +			\
				str(pict_info["nr_slideshows"]) + ";" + 	\
				pict_info["first_slideshow"] + ";" +  		\
				pict_info["last_slideshow"] + ";" + "\n"
				f.write(rec)								
		f.close()
		json_fi = Path(fi)
		if json_fi.is_file() :
			os.remove(json_fi)				
			print("Deleted: ", json_fi)
	
		
ret_stat, conf_params = read_config_file()
##if ret_stat == "ok" :

status, port_nr = is_port_nr_valid() 
if not status :
	exit()

file_dates = get_dates_for_clicks_per_day_and_tablet(port_nr)
if len(file_dates) > 0 : 
	for fi_dt in file_dates:
		if g_detailed_logging == 1: 
			print()
		clicks_per_day_and_tablet_to_one(fi_dt, port_nr)
		
	if g_detailed_logging == 1: 
		print()	
	clicks_per_day_and_tablet(port_nr)

	if g_detailed_logging == 1: 
		print()

	
clicks_per_run_and_tablet(port_nr)

