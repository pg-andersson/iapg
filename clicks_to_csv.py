#!/usr/bin/python3
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2024 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

import sys
import platform
import os
import glob
import json
from datetime import datetime

g_base="."  
g_var_dir = g_base + "/var"
g_stat_dir = g_var_dir + "/stat"

g_detailed_logging = 0

def get_stat_file_dates() :
	files = []
	for fi in glob.glob(g_stat_dir+"/*_clicks*.json") : 
		fi_pref = fi.split("_clicks")[0]
		f_parts = fi_pref.split("/")
		fi_dt = f_parts[len(f_parts) -1]
		if fi_dt not in files :
			files.append(fi_dt)
	return(files)


def convert_simple_stat_files_to_one(fi_dt) :
	if g_detailed_logging == 1: 
		print("convert_simple_stat_files_to_one", fi_dt)
	recs = []
	click_summary = {}
	for fi in glob.glob(g_stat_dir+"/*_clicks*.json") : 
		fi_pref = fi.split("_clicks")[0]
		f_parts = fi_pref.split("/")
		this_fi_dt = f_parts[len(f_parts) -1]
		if this_fi_dt != fi_dt :
			continue
		
		fi_csv = fi_pref+"_click_summary.csv"
		if g_detailed_logging == 1: 
			print(fi)
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
		

def convert_simple_stat_files() :
	if g_detailed_logging == 1: 
		print("convert_simple_stat_files")
	for fi in glob.glob(g_stat_dir+"/*_clicks_*.json") : 
		fi_pref = fi.split(".json")[0]
		fi_csv = fi_pref+".csv"
		if g_detailed_logging == 1: 
			print(fi+" => "+ fi_csv)
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
			
			
def convert_detailed_stat_files() :
	if g_detailed_logging == 1: 
		print("convert_detailed_stat_files")
	for fi in glob.glob(g_stat_dir+"/clicks_*.json") : 
		fi_pref = fi.split(".json")[0]
		fi_csv = fi_pref+".csv"	
		if g_detailed_logging == 1: 
			print(fi+" => "+ fi_csv)
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

		
file_dates = get_stat_file_dates()
for fi_dt in file_dates:
	if g_detailed_logging == 1: 
		print()
	convert_simple_stat_files_to_one(fi_dt)
	
if g_detailed_logging == 1: 
	print()	
convert_simple_stat_files()

if g_detailed_logging == 1: 
	print()
convert_detailed_stat_files()


