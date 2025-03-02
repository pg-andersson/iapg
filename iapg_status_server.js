// This file is part of iapg (Interactive Photo Gallery).
// Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
// iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

// This javascript is started by iapg_kiosk.sh or iapg_start_server.sh. It creates web pages with information about the picture server and the kiosks.

"use strict"

const fs = require("fs")
const path = require('path')
const http = require("http")
const express = require("express")
const os = require('os');
const process = require('process')
const g_my_pid = process.pid

const g_base = os.homedir() + "/iapg-main" 
const g_etc_dir = g_base + "/etc"
const g_html_dir = g_base + "/html"
const g_var_dir = g_base + "/var"
const g_log_dir = g_var_dir + "/log"
const g_stat_dir = g_var_dir + "/stat"

const g_fi_serv_conf = g_etc_dir + "/iapg_server.conf"
const g_fi_kiosk_conf = g_etc_dir + "/iapg_kiosk.conf"

const g_fi_clublist = g_etc_dir + "/clublist.conf"
const g_fi_active_servers = g_log_dir + "/active_servers"
const g_fi_active_servers_pid = g_log_dir + "/active_servers_pid"
const g_fi_active_router = g_log_dir + "/active_router.txt"
const g_fi_server_dir_tree = g_log_dir + "/a_server_dir_tree.txt"
const g_fi_serv_stat = g_log_dir + "/a_status_server_status.txt"

var g_port_nr = 53000
var g_server_type = "picture_server"
var scripts_added = false

var g_addr_server = ""
var g_kiosk_port_nr = ""
var g_kiosk_club_id = ""

if (fs.existsSync(g_fi_serv_stat)) {
	fs.unlinkSync(g_fi_serv_stat) 
	console.log("Deleted: " + g_fi_serv_stat)							
}

console.log("Platform: " + os.platform())
console.log("homedir: " + g_base)

get_arg()	
console.log("listen on port:" + g_port_nr + " " + g_server_type )

var app = express()

if (g_server_type == "picture_server") {
	app.use(express.static('./html/picture_server'))
	app.use(express.static('./html'))
	console.log("express.static: ./html/picture_server")
} else {
	app.use(express.static('./html/display_server'))
	console.log("express.static: ./html/display_server")
}

app.use(express.urlencoded({ extended: false }))

http.createServer(app).listen(g_port_nr)

let rec = get_timestamp(true) + " Started pid=" + g_my_pid + "\n"
fs.writeFileSync(g_fi_serv_stat, rec)	

app.get("/", function (req, res) {
	console.log(get_timestamp(true) + " app.get /")
	res.sendFile("./index.html")						 
})

app.post("/view_status", function (req, res) {
	console.log(get_timestamp(true) + " /view_status req.body:\n", JSON.stringify(req.body))

	let fi_html = ""
	
	if (g_server_type == "picture_server") 
		fi_html = g_html_dir + "/picture_server/index.html"
	else
		fi_html = g_html_dir + "/display_server/index.html"

	let resp_txt = prepare_new_input(fi_html)
	
	if (g_server_type == "display_server") {
		get_kiosk_par()
		resp_txt = resp_txt + "<strong>" + g_kiosk_club_id + " " + g_kiosk_port_nr +  "</strong><br \><br \>" 		
	}
	
	resp_txt = resp_txt + "<h3>" + get_timestamp(true) + " Last Status Update</h3>"
	
	if (g_server_type == "picture_server") 
		resp_txt = resp_txt + resp_picture_server(req)
	else 
		resp_txt = resp_txt + resp_display_server(req)
	
	resp_txt = resp_txt + "</body></html>"	
	res.send(resp_txt)
})


if (g_server_type == "picture_server" || g_server_type == "display_server" ){
	app.post("/status_snapshot", function (req, res) {
		let fi_html = ""

		if (g_server_type == "picture_server")
			fi_html = g_html_dir + "/picture_server/status_snapshot.html"
		else
			fi_html = g_html_dir + "/display_server/status_snapshot.html"
				
		let resp_txt = prepare_status_snapshot(fi_html)
		
		if (g_server_type == "display_server") {
			get_kiosk_par()
			resp_txt = resp_txt + "<strong>" + g_kiosk_club_id + " " + g_kiosk_port_nr +  "</strong><br \><br \>" 		
		}

		resp_txt = resp_txt + "<b>Last refresh = " + get_timestamp(true) + "<br><p style='font-size:130%'></b>"
		resp_txt = resp_txt + list_errors()		
		resp_txt = resp_txt + list_error_status()
		
		resp_txt = resp_txt + "</body></html>"	
		res.send(resp_txt)
	})
}


if ( g_server_type == "display_server" ){
	app.post("/kiosk_startup_problems", function (req, res) {
		let fi_html = ""

		fi_html = g_html_dir + "/display_server/kiosk_startup_problems.html"
				
		let resp_txt = prepare_status_snapshot(fi_html)
		
		resp_txt = resp_txt + "The kiosk address = " + get_kiosk_address() + "<br \><br \>"

		resp_txt = resp_txt + "<b>Last refresh = " + get_timestamp(true) + "<br><p style='font-size:130%'></b>"
				
		resp_txt = resp_txt + "<pre>"
		resp_txt = resp_txt + g_fi_kiosk_conf + "<br \>"
		resp_txt = resp_txt + read_iapg_file(false, g_fi_kiosk_conf)
		resp_txt = resp_txt + "</pre>"
		
		get_kiosk_par()
		resp_txt = resp_txt + "<strong>" + g_addr_server + " " + g_kiosk_club_id + " " + g_kiosk_port_nr +  "</strong><br \><br \>" 		

		resp_txt = resp_txt + list_errors()		
		resp_txt = resp_txt + list_error_status()
		
		resp_txt = resp_txt + "</body></html>"	
		res.send(resp_txt)
	})
}


function prepare_status_snapshot(fi_html) {
	let resp_txt = ""
	
	try {
		var data = fs.readFileSync(fi_html, 'utf8').toString()
		let params = data.split('\n')
		for (let param of params) {
			if (param == "") {
				continue
			}		
			if (param.startsWith("</body>")) {
				return(resp_txt)
			}	
			resp_txt = resp_txt + param + "\n"
		}
	} catch (err) {
		console.error(err)
		return(err)
	}
}


function prepare_new_input(fi_html) {
	let resp_txt = ""
	
	try {
		var data = fs.readFileSync(fi_html, 'utf8').toString()
		let params = data.split('\n')
		for (let param of params) {
			if (param == "") {
				continue
			}		
			if (param.startsWith("</body>")) {
				return(resp_txt)
			}	
			resp_txt = resp_txt + param
		}
	} catch (err) {
		console.error(err)
		return(err)
	}
}
	

function read_iapg_file(skip_empty_lines, fi) {
	let resp_txt = ""
	
	try {
		var data = fs.readFileSync(fi, 'utf8').toString()
		let params = data.split('\n')
		for (let param of params) {
			param = param.trim()
			let param_tmp = param.replace(/ /g, "")
			if (param_tmp.startsWith("#")) {
				continue
			}
			if (skip_empty_lines) {
				if (param_tmp == "") 
					continue
			}		
			resp_txt = resp_txt + param + "<br \>"
		}	
		return(resp_txt)
	} catch (err) {
		console.error(err)
		return(err)
	}
}


function list_errors()
{		
	let resp_txt = ""
	let fi_status = ""
	let fi_member_dir_error = ""

	fi_status = g_log_dir + "/a_kiosk_start_err.txt"
	if (fs.existsSync(fi_status)) {
		resp_txt = resp_txt + "<div class='config_err'>"
		resp_txt = resp_txt + "THE PICTURE SERVER IS NOT AVAILABLE<br \>"
		resp_txt = resp_txt + read_iapg_file(false, fi_status)
		resp_txt = resp_txt + "Is the picture server connected?<br \>"
		resp_txt = resp_txt + "Is the addr_server= correct?<br \>"
		resp_txt = resp_txt + "</div><br \>"
		resp_txt = resp_txt + "If the addr_server= is wrong the kiosk will try the new one as soon as you have updated it in the config file.<br \>"		
		resp_txt = resp_txt + "If the server was disconnected the kiosk will try it regularly to see if it is reconnected.<br \><br \>"		
	}

	fi_status = g_log_dir + "/a_kiosk_network_start_err.txt"
	if (fs.existsSync(fi_status)) {
		resp_txt = resp_txt + "<div class='config_err'>"
		resp_txt = resp_txt + "THE NETWORK IS NOT AVAILABLE<br \>"
		resp_txt = resp_txt + read_iapg_file(false, fi_status)
		resp_txt = resp_txt + "Is the router up? <br \>"
		resp_txt = resp_txt + "Is the SSID and the password for the WiFi in the router the same as the one you entered when you created the boot image with Raspberry Pi Imager? <br \>"
		resp_txt = resp_txt + "</div><br \>"
		resp_txt = resp_txt + "If the router was down, the kiosk will try it as soon as it is up again.<br \>"		
		resp_txt = resp_txt + "If the router is up it is likely that the WiFi password is wrong.<br \>"	
		resp_txt = resp_txt + "If the WiFi password is wrong in the kiosk the best is to create a new image. There is no easy way to change it on the kiosk.<br \><br \>"		
	}
	
	fi_status = g_log_dir + "/a_config_error.txt"
	if (fs.existsSync(fi_status)) {
		resp_txt = resp_txt + "<div class='config_err'>"
		resp_txt = resp_txt + "AN ERROR IN THE CONFIGURATION FILES MUST BE FIXED BEFORE SYSTEM STARTS <br \>"
		resp_txt = resp_txt + read_iapg_file(false, fi_status)
		resp_txt = resp_txt + "</div>"
	}

	fi_status = g_log_dir + "/a_conf_started_clubs.txt"
	if (fs.existsSync(fi_status)) {
		//resp_txt = resp_txt +  "<strong>Started Clubs with missing signature pictures or an empty club-dir</strong><br \>"	
		var data = fs.readFileSync(fi_status, 'utf8').toString()
		let s = ""
		let club = ""
		let port = ""
		fi_member_dir_error = ""
		let lines = data.split('#')
		for (let line of lines) {
			s = line.split(":")
			club = s[0]
			port = s[1]			
			fi_member_dir_error = g_log_dir + "/a_member_dir_error_" + club + "_" + port
			if (fs.existsSync(fi_member_dir_error)) {				
				resp_txt = resp_txt + "<div class='config_err'>"
				//resp_txt = resp_txt + "The signature picture is missing.<br \>"
				//resp_txt = resp_txt + read_iapg_file(false, fi_member_dir_error)
				var rec = fs.readFileSync(fi_member_dir_error, 'utf8').toString()
				rec = rec.trim()
				resp_txt = resp_txt + rec + "<br \>"							
				if (rec.search("No signature-file") > -1) 
					resp_txt = resp_txt + "The signature picture is missing.<br \>"
				else
					if (rec.search("No member") > -1) 
						resp_txt = resp_txt + "The club directory has no member directories. Are they removed? Is the club in the clublist a leftover?<br \>"
					else
						if (rec.search("No pictures") > -1) 
							resp_txt = resp_txt + "The member directory has no pictures.<br \>"
						
				resp_txt = resp_txt + "</div>"
			}
		}	
	}
	
	if (resp_txt == "" ) {
		resp_txt = resp_txt + "<div class='config_ok'>"
		resp_txt = resp_txt + "No obvious configuration errors found.<br \>"
		resp_txt = resp_txt + "</div>"
	}
	
	return(resp_txt)
}


function list_error_status()
{		
	let resp_txt = ""
	let fi_status = ""
		
	fi_status = g_log_dir + "/a_start_status.txt"
	if (fs.existsSync(fi_status)) {
		resp_txt = resp_txt +  "<strong>Start Status</strong><br \>"
		resp_txt = resp_txt + read_iapg_file(false, fi_status)
	}		
	
	fi_status = g_log_dir + "/a_conf_info_started_clubs.txt"
	if (fs.existsSync(fi_status)) {
		resp_txt = resp_txt +  "<strong>Started Clubs</strong><br \>"	
		var data = fs.readFileSync(fi_status, 'utf8').toString()
		let nr = 0
		let s = ""
		let cur_club = ""
		let prev_club = ""
		let lines = data.split('#')
		for (let line of lines) {
			if (nr == 0) {
				resp_txt = resp_txt + line + "<br \>"
				nr = nr + 1
			} else {
				s = line.split(" ")
				cur_club = s[0]
				if (cur_club != prev_club) {
					prev_club = cur_club
					resp_txt = resp_txt + "<br \>"
				}	
				resp_txt = resp_txt + line + "<br \>"
			}
		}
	}	

	fi_status = g_log_dir + "/a_config_status.txt"
	if (fs.existsSync(fi_status)) {
		resp_txt = resp_txt +  "<strong>Configuration Status</strong><br \>"
		resp_txt = resp_txt + read_iapg_file(false, fi_status)
	}	
	
	if (fs.existsSync(g_fi_active_servers_pid)) {
		resp_txt = resp_txt +  "<strong>Club Servers PID</strong><br \>"
		var data = fs.readFileSync(g_fi_active_servers_pid, 'utf8').toString()
		let pids = data.split('\n')
		resp_txt = resp_txt + "<pre>"
		for (let pid of pids) {		
			resp_txt = resp_txt + pid +  "<br \>"
		}
		resp_txt = resp_txt + "</pre>"
	}	

	//Get the active kiosks for this club. One file per club and port.
	if (fs.existsSync(g_fi_active_servers)) {
		var data = fs.readFileSync(g_fi_active_servers, 'utf8').toString()
		let club_dirs = data.split('\n')
		for (let club_dir of club_dirs) {
			fi_status = g_log_dir + "/active_kiosks_" + club_dir	
			if (fs.existsSync(fi_status)) {
				resp_txt = resp_txt + "<strong>" +  "Active kiosks for " + club_dir + "</strong><br \>"
				var data = fs.readFileSync(fi_status, 'utf8').toString().trim()
				let ips = data.split('#')
				resp_txt = resp_txt + "<pre>"
				
				for (let ip of ips) {
					if (ip != "" ) {
						// "2025-02-14_16:22:50 kiosk=1 ::ffff:10.0.1.131" 
						let ip_kiosk = ip.split(" ")[2].split(":")[3]
						resp_txt = resp_txt + ip +  ' View the status: '  + '<a href=http://' + ip_kiosk + ':53000/index.html target="_blank">The monitor in the kiosk for ' + club_dir + ' </a><br \>'					
					}
				}
				resp_txt = resp_txt + "</pre>"			
			}
		}
	}
	
	//Router alive?
	if (fs.existsSync(g_fi_active_router)) {
		resp_txt = resp_txt + "<div class='config_err'>"
		resp_txt = resp_txt + "Network problems.<br \>"
		resp_txt = resp_txt + read_iapg_file(false, g_fi_active_router)
		resp_txt = resp_txt + "</div>"
	}

	//Get  the ID of the clubs. One status file per club and kiosk.
	if (fs.existsSync(g_fi_active_servers)) {
		var data = fs.readFileSync(g_fi_active_servers, 'utf8').toString()
		let club_dirs = data.split('\n')
		for (let club_dir of club_dirs) {
			fi_status = g_log_dir + "/actions_server_" + club_dir	
			if (fs.existsSync(fi_status)) {
				resp_txt = resp_txt + "<strong>" +  "Server actions for " + club_dir + "</strong><br \>"
				resp_txt = resp_txt + read_iapg_file(false, fi_status)
			}
		}
	}
	
	return(resp_txt)
}		


function list_clubdirs() 
{
	let resp_txt = "<h2>The Clubs, the Members and the Pictures</h2>"
	let fi_cn = ""
	let cn = ""
	let first_club = true
	
	let club_dirs = fs.readdirSync(g_html_dir)
	for (let club_dir of club_dirs) {
		let full_path = g_html_dir + "/" + club_dir
		if (fs.statSync(full_path).isDirectory()) {
			if (club_dir.startsWith("club-")) {
				cn = ""
				fi_cn = g_var_dir + "/" + club_dir + "_club_name.txt"
				if (fs.existsSync(fi_cn)) {
					cn = fs.readFileSync(fi_cn, 'utf8').toString()
				}					
				//resp_txt = resp_txt + "<h3>" + club_dir + " " + cn + "</h3>"
				let memb_dirs = fs.readdirSync(full_path)
				for (let memb_dir of memb_dirs) {
					full_path = g_html_dir + "/" + club_dir + "/" + memb_dir
					if (fs.statSync(full_path).isDirectory()) {
						if ( first_club) {
							first_club = false
						} else {
							resp_txt = resp_txt + '<hr class="dashed">'
						}				
						//resp_txt = resp_txt + "<strong>" + club_dir + " : " + cn + " &#x2192; member : " + memb_dir + "</strong><br \><br \>"
						resp_txt = resp_txt + "<strong>" + club_dir + " : " + cn + "<br \>Member : " + memb_dir + "</strong><br \><br \>"
						let memb_files = fs.readdirSync(full_path)
						for (let memb_file of memb_files) {
								if (memb_file.endsWith(".jpg")) { 
								resp_txt = resp_txt + '<img src="' + club_dir + '/' + memb_dir + '/' + memb_file + '"' + ' width="auto" height="600" /><br \>'
								resp_txt = resp_txt + club_dir + " : " + cn + " &#x2192; " + memb_dir + " &#x2192; " + memb_file + "<br \><br \>"
							}
						}
					}
					resp_txt = resp_txt + "<br \>"
				}		
			}
		}
	}
	return(resp_txt)
}


function list_tree()
{
	let resp_txt = "<h2>The directory structure</h2>"
	if (fs.existsSync(g_fi_server_dir_tree)) {
		var data = fs.readFileSync(g_fi_server_dir_tree, 'utf8').toString()
		let lines = data.split('\n')
		resp_txt = resp_txt + "<pre>"
		for (let line of lines) {		
			resp_txt = resp_txt + line +  "<br \>"
		}
		resp_txt = resp_txt + "</pre>"
	}
	return(resp_txt)
}


function cre_table_click_header(row)
{
	let resp_txt = ""
	
	resp_txt = resp_txt + "<tr class='header'>"	
	let cols = row.split(';')
	for (let col of cols) {
		resp_txt = resp_txt + "<td align='left'>" + col + "</td>"	
	}	
	resp_txt = resp_txt + "</tr>"
	
	return(resp_txt)
}


function cre_table_click_row(row)
{
	let resp_txt = ""
	
	resp_txt = resp_txt + "<tr align=left>"		
	let cols = row.split(';')
	for (let col of cols) {
		resp_txt = resp_txt + "<td align='left'>" + col + "</td>"	
	}	
	resp_txt = resp_txt + "</tr>"

	return(resp_txt)
}


function cre_table_click_rows(stat_file) {
	let resp_txt = ""
	
	try {
		var data = fs.readFileSync(g_stat_dir + "/" + stat_file, 'utf8').toString()
		let rows = data.split('\n')
		resp_txt = resp_txt + cre_table_click_header(rows[0].trim())			
		for (let i = 1; i < rows.length; i++) {
			resp_txt = resp_txt + cre_table_click_row(rows[i].trim())	
		}		
		return(resp_txt)
	} catch (err) {
		console.error(err)
		return(err)
	}
}


function  cre_table_click_stat(stat_file, click_type)
{
	let s = ""
	let p = ""
	let n = 0
	let club = ""
	let tablet = ""

	let resp_txt = ""
	if (!scripts_added) {
		scripts_added = true
		resp_txt = resp_txt + "<script type='text/javascript' src='sorttable.js'></script><meta http-equiv='Pragma'>"
		resp_txt = resp_txt + "<style type='text/css'>body {background-color:#f8f8f8;} table {border-collapse:collapse;} table, td, th {border:1px solid black;} tr.header {font-weight:bold; background-color: #04AA6D; color: white; } td.col1 {padding-left: 2em;text-align: left;white-space: nowrap;} td.col {padding-left: 2em;text-align: right;white-space: nowrap;}</style>" 
		resp_txt = resp_txt + "<style type='text/css'>table.sortable thead{background-color:#eee; color:#666666; font-weight: bold cursor: default;} td { padding: 4px; cellspacing: 8px; } table {border-spacing: 4px; border-collapse: collapse;}</style>"
	}
	
	resp_txt = resp_txt + "<br \>"
	resp_txt = resp_txt + "<table class='sortable'>"
	if (click_type == "clicks_") {
		// Get the club and tablet number from the port number in the file name.
		s = stat_file.split("_")
		p = s[1]
		n = parseInt(p.substring(2, 4)) + 1
		club = "club_" + n
		tablet = p.substring(p.length -1)				
		resp_txt = resp_txt + "<caption>" + club + " Tablet nr:" + tablet + " " + stat_file + "</caption>"
	}

	if (click_type == "_clicks_") {
		// Get the club and tablet number from the port number in the file name.
		 s = stat_file.split("_")
		 p = s[2]
		 n = parseInt(p.substring(2, 4)) + 1
		 club = "club_" + n
		 tablet = p.substring(4, 5)				
		resp_txt = resp_txt + "<caption>" + club + " Tablet nr:" + tablet + " " + stat_file + "</caption>"
	}

	if (click_type == "") {
		resp_txt = resp_txt + "<caption>" + stat_file + "</caption>"
	}	
	
	resp_txt = resp_txt + cre_table_click_rows(stat_file)			
	resp_txt = resp_txt + "</table>"
	
	return(resp_txt)
}


function list_click_summary()
{
	let resp_txt = ""

	resp_txt = resp_txt + "<h3>Summary of clicks</h3>"
	
	let stat_files = fs.readdirSync(g_stat_dir)
	for (let stat_file of stat_files) {
		if (stat_file.endsWith("click_summary.csv")) {
			resp_txt = resp_txt + "<hr>"
			resp_txt = resp_txt + cre_table_click_stat(stat_file, "")
		}
	}

	return(resp_txt)
}


function list_clicks_per_run_and_tablet()
{
	let resp_txt = ""

	resp_txt = resp_txt + "<h3>Clicks per run and tablet</h3>"
	
	let stat_files = fs.readdirSync(g_stat_dir)
	for (let stat_file of stat_files) {
		if (stat_file.startsWith("clicks_") && stat_file.endsWith(".csv")) {
			resp_txt = resp_txt + "<hr>"
			resp_txt = resp_txt + cre_table_click_stat(stat_file, "clicks_")
		}
	}

	return(resp_txt)
}


function list_clicks_per_day_and_tablet()
{
	let resp_txt = ""
	
	resp_txt = resp_txt + "<h4>Clicks per day and tablet</h4>"
	
	let stat_files = fs.readdirSync(g_stat_dir)
	for (let stat_file of stat_files) {
		if ((stat_file.search("_clicks_")>0) && stat_file.endsWith(".csv")) {
			resp_txt = resp_txt + "<hr>"
			resp_txt = resp_txt + cre_table_click_stat(stat_file, "_clicks_")
		}
	}

	return(resp_txt)
}


function resp_picture_server(req) {
	let resp_txt = ""
	scripts_added = false

	resp_txt = list_errors()
	
	if (req.body.errors) {
		console.log(get_timestamp(true) + " errors:" + req.body.errors)
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_error_status()
	}
	
	if (req.body.config) {
		resp_txt = resp_txt + "<hr>"
		if (fs.existsSync(g_fi_serv_conf)) {
			resp_txt = resp_txt + "<strong>iapg_server.conf</strong><br \>"
			resp_txt = resp_txt + "<pre>"
			resp_txt = resp_txt + read_iapg_file(false, g_fi_serv_conf)
			resp_txt = resp_txt + "</pre>"
		} else {
			resp_txt = resp_txt + g_fi_serv_conf + " does not exist."
		}
	}

	if (req.body.clublist) {
		resp_txt = resp_txt + "<hr>"
		if (fs.existsSync(g_fi_clublist)) {
			resp_txt = resp_txt + "<strong>iapg_clublist.conf</strong><br \><br \>"
			resp_txt = resp_txt + "<pre>"
			resp_txt = resp_txt + read_iapg_file(false, g_fi_clublist)
			resp_txt = resp_txt + "</pre>"
		} else {
			resp_txt = resp_txt + g_fi_clublist + " does not exist."
		}
	}

	if (req.body.clubdir) {
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_clubdirs()
	}	
	
	if (req.body.tree) {
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_tree()
	}	


	if (req.body.click_summary) {
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_click_summary()
	}	

	if (req.body.list_clicks_per_day_and_tablet) {
		console.log(get_timestamp(true) + " list_clicks_per_day_and_tablet:" + req.body.list_clicks_per_day_and_tablet)
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_clicks_per_day_and_tablet()
	}	

	if (req.body.list_clicks_per_run_and_tablet) {
		console.log(get_timestamp(true) + " list_clicks_per_run_and_tablet:" + req.body.list_clicks_per_run_and_tablet)
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_clicks_per_run_and_tablet()
	}	

	return(resp_txt)
}


function resp_display_server(req) {
	let resp_txt = ""

	resp_txt = list_errors()

	if (req.body.errors) {
		resp_txt = resp_txt + "<hr>"
		resp_txt = resp_txt + list_error_status()
	}
	
	if (req.body.config) {
		resp_txt = resp_txt + "<hr>"
		if (fs.existsSync(g_fi_kiosk_conf)) {
			resp_txt = resp_txt + "iapg_kiosk.conf <br \>"
			resp_txt = resp_txt + read_iapg_file(false, g_fi_kiosk_conf)
		} else {
			resp_txt = resp_txt + g_fi_kiosk_conf + " does not exist."
		}
	}

	return(resp_txt)
}


function get_kiosk_par()
{
	let s = ""
	if (fs.existsSync(g_fi_kiosk_conf)) {
		var data = fs.readFileSync(g_fi_kiosk_conf, 'utf8').toString()
		let params = data.split('\n')
		for (let param of params) {
			param = param.trim()
			let param_tmp = param.replace(/ /g, "")
			if (param_tmp.startsWith("addr_server=")) {
				s = param_tmp.split("=")
				g_addr_server = s[1]
			}
			if (param_tmp.startsWith("club_id=")) {
				s = param_tmp.split("=")
				g_kiosk_club_id = s[1]
			}
			if (param_tmp.startsWith("port_nr_for_this_kiosk=")) {
				s = param_tmp.split("=")
				g_kiosk_port_nr = s[1]
			}
		}
	}
}


function get_arg()
{
	if (process.argv.length !== 4) {
		console.log("Invalid arguments: port_nr server_type")
		process.exit()
	}	
	g_port_nr = process.argv[2]	
	g_server_type = process.argv[3]	
}


function get_timestamp(with_colon)
{
	const d = new Date()
	let tmp = d.toLocaleString("sv")
	tmp = tmp.replace(" ", "_")
	if (!with_colon) {
		tmp = tmp.replace(/:/g, "")	
	}
	return(tmp)
}


function get_kiosk_address() 
{
	let server_address_v4 = ""
	let server_address_v6 = ""
	let networkInterfaces = os.networkInterfaces();

	//console.log(os.networkInterfaces())
	
	for (let netint in networkInterfaces) {
		for (let iface of networkInterfaces[netint]) {
			if (iface.family == "IPv4") {
				server_address_v4 = iface.address
			}
			if (iface.family == "IPv6") {
				server_address_v6 = iface.address
			}
		}
	}

	if (server_address_v4 != "") 
		return(server_address_v4)
	else
		return(server_address_v6)	
}

