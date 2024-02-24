// This file is part of iapg (Interactive Photo Gallery).
// Copyright (C) 2024 PG Andersson <pg.andersson@gmail.com>.
// iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later
// This javascript serves clients with either thumbnails or pictures.

"use strict"

let g_logging = "0"		// Documented in iapg.conf 

const fs = require("fs")
const http = require("http")
const express = require("express")
const os = require('os');
const process = require('process');

const g_base = "."  
const g_etc_dir = g_base + "/etc"
const g_html_dir = g_base + "/html"
const g_var_dir = g_base + "/var"
const g_log_dir = g_var_dir + "/log"
const g_stat_dir = g_var_dir + "/stat"

const g_fi_conf = g_etc_dir + "/iapg.conf"

let g_club_dir
let g_port_nr
let g_waittime_before_slideshow_start =  1*60000
let g_pict_displaytime_slideshow =  10*1000

console.log("Platform: " + os.platform());
get_arg()	
get_server_conf()
console.log("listen on port:" + g_port_nr)
console.log("waittime_before_slideshow_start= ", g_waittime_before_slideshow_start)
console.log("pict_displaytime_slideshow= ", g_pict_displaytime_slideshow)

const g_fi_clicks = g_stat_dir + "/" + get_date() + "_clicks_" + g_port_nr + ".json"
const g_fi_click_ports = g_stat_dir + "/clicks_" + g_port_nr + "_" + get_timestamp() + ".json"

var app = express()
app.use(express.static('./html'))
app.use(express.urlencoded({ extended: false }))
http.createServer(app).listen(g_port_nr)

var g_show_clients = []
var g_show_url = "photo-camera.svg"

var g_slideshow_urls = []
let g_next_slide_to_show = 0

let g_id_slideshow_timeout = undefined;

let g_server_address = get_server_address() 
console.log(g_server_address)

let g_click_stats = {}
let g_click_stats_simple = {}

let g_members_display_info = {}
load_members_display_info()	// Must reload the display_info in case the iapg gets restarted while the control client still has an index page.

start_slideshow()			// Let the slideshow run to start with.


function get_arg()
{
	if (process.argv.length !== 4) {
		console.log("Invalid arguments: club_dir port_nr ")
		process.exit()
	}
	
	g_club_dir = process.argv[2]	
	g_port_nr = process.argv[3]
}


function get_timestamp()
{
	const d = new Date()
	let tmp = d.toISOString().replace("T", "_")
	tmp = tmp.replace(/:/g, "")
	return(tmp.slice(0, tmp.lastIndexOf(".")))
}


function get_date()
{
	const d = new Date()
	let tmp = d.toISOString().replace("T", "_")
	tmp = tmp.split("_")
	return(tmp[0])
}


function get_server_address() 
{
	let server_address_v4 = ""
	let server_address_v6 = ""
	let networkInterfaces = os.networkInterfaces();
	if (g_logging.includes("1"))
		console.log(get_timestamp() + " 1\n" + networkInterfaces)

	for (let netint in networkInterfaces) {
		for (let iface of networkInterfaces[netint]) {
			if (!iface.internal) {
				if (iface.family == "IPv4")
					server_address_v4 = iface.address
				if (iface.family == "IPv6")
					server_address_v6 = iface.address
			}
		}
	}
	if (server_address_v4 != "") 
		return(server_address_v4)
	else
		return(server_address_v6)	
}


function get_server_conf()
{
	try {
		var data = fs.readFileSync(g_fi_conf, 'utf8').toString()
		let params = data.split('\n')
		let val = 0
		for (let param of params) {
			param = param.trim()
			param = param.replace(/ /g, "")
			if (param.startsWith("#")) {
				continue
			}		
			if (param.startsWith("logging")) {
				console.log(param)
				g_logging = param.split('=').pop()
				//g_logging = val.trim()
				if (g_logging.includes("2"))
					console.log(get_timestamp() + " 2 \n" + params)
			}		
			if (param.startsWith("waittime_before_slideshow_start")) {
				val = param.split('=').pop()
				//val = val.trim()
				g_waittime_before_slideshow_start = val * 1000
			}
			if (param.startsWith("pict_displaytime_slideshow")) {
				val = param.split('=').pop()
				//val = val.trim()
				g_pict_displaytime_slideshow = val * 1000
			}			
		}
	} catch (err) {
		console.error(err)
	}
}


function get_club_name(base_club_dir)
{
	// Get the club's name from club_name.txt
	let club_name = g_club_dir
	let fi_club = base_club_dir + "/club_name.txt"
	try {
		var data = fs.readFileSync(fi_club, 'utf8').toString();
		club_name = data.trim()		
	} catch (err) {
		club_name = g_club_dir
	}
console.log(club_name)
	return(club_name)
}

function init_pict_click()
{
	// Click stats per club_member.
	for (let member in g_members_display_info) {
		let member_click_stats = {}
		let member_picts_info = []
		for (let picture of g_members_display_info[member].pictures) {	
			let pict_info = {}					
			pict_info.pict = picture.split('/').pop()	// pictures/A Andersson/A good picture.jpg?member_fullname=A Andersson%club_name=xyz
			pict_info.nr_userclicks = 0
			pict_info.first_userclick = ""
			pict_info.last_userclick = ""
			pict_info.nr_slideshows = 0
			pict_info.first_slideshow = ""
			pict_info.last_slideshow = ""
			member_picts_info.push(pict_info)
		}
		member_click_stats.member_fullname = member
		member_click_stats.picts_info = member_picts_info		
		g_click_stats[member] = member_click_stats		
	}
}


function update_pict_click_simple(fi, request_type)
{
	if (fs.existsSync(g_fi_clicks)) {
		g_click_stats_simple = JSON.parse(fs.readFileSync(g_fi_clicks, "utf-8"))
	}
		
	if (fi in g_click_stats_simple) {
		if (request_type == "user_click" )
			g_click_stats_simple[fi].nr_userclicks++ 
		else 
			g_click_stats_simple[fi].nr_slideshows++ 			
	} else {
		let pict_info = {}
		pict_info.nr_userclicks = 0
		pict_info.nr_slideshows = 0
		if (request_type == "user_click" )
			pict_info.nr_userclicks = 1
		else
			pict_info.nr_slideshows = 1	
			
		g_click_stats_simple[fi] = pict_info
	}	
    fs.writeFileSync(g_fi_clicks, JSON.stringify(g_click_stats_simple,0 , 4))	
}


function update_pict_click(request_type)
{
	// pictures/A Andersson/A good picture.jpg?member_fullname=A Andersson%club_name=xyz

	let q = g_show_url.split("?")	
	let pict = q[0].split("/").pop()
	let a = q[1].split("&")
	let member = a[0].split("=").pop()
	let fi = member+"/"+pict

	update_pict_click_simple(fi, request_type)	
	
	// Get the index for this picture
	let ix = 0
	let found = false
	for ( let pict_info of g_click_stats[member].picts_info ) {
		if (pict_info.pict == pict) {
			found = true
			break
		}
		ix++
	}
	if (!found) {
		console.log("Not found", ix, pict)
		return(0)
	}
		
	if (request_type == "user_click" ) {
		g_click_stats[member].picts_info[ix].nr_userclicks++  
		if (g_click_stats[member].picts_info[ix].first_userclick == "") {
			g_click_stats[member].picts_info[ix].first_userclick = get_timestamp()
		}
		g_click_stats[member].picts_info[ix].last_userclick = get_timestamp() 
	} else {
		g_click_stats[member].picts_info[ix].nr_slideshows++ 
		if (g_click_stats[member].picts_info[ix].first_slideshow == "") {
			g_click_stats[member].picts_info[ix].first_slideshow = get_timestamp()
		}
		g_click_stats[member].picts_info[ix].last_slideshow = get_timestamp() 
	}
	fs.writeFileSync(g_fi_click_ports, JSON.stringify(g_click_stats, 0, 4))
}


function send_update_show_clients() {
	if (g_logging.includes("6")) {
		console.log(get_timestamp() + " 6 send_update_show_clientsBeg. g_show_url")	
		console.log(g_show_url)	
	}
	for (let res of g_show_clients) {
		res.write("event: show\n")
		res.write("data: " + JSON.stringify(g_show_url) + "\n\n")
	}
	if (g_logging.includes("6"))
		console.log(get_timestamp() + " 6 send_update_show_clientsEnd\n")	
}


function start_slideshow()
{	
	if (g_logging.includes("7"))
		console.log(get_timestamp() + " 7 start_slideshowBeg ix: " + g_next_slide_to_show)	
				
	g_show_url = g_slideshow_urls[g_next_slide_to_show]
	update_pict_click("slideshow")
	send_update_show_clients()

	g_next_slide_to_show++
	if ( g_next_slide_to_show == g_slideshow_urls.length)
		g_next_slide_to_show = 0	
		
	// Set a time to wait before the next slide is sent.
	g_id_slideshow_timeout = setTimeout(start_slideshow, g_pict_displaytime_slideshow)
	if (g_logging.includes("7"))
		console.log(get_timestamp() + " 7 start_slideshowEnd. Next in " + g_pict_displaytime_slideshow/1000 + " sec, timeout_id: " + g_id_slideshow_timeout + "\n")
}


function update_show_clients() {
	if (g_logging.includes("5"))
			console.log(get_timestamp() + " 5 update_show_clientsBeg: Cleared timeout_id: " + g_id_slideshow_timeout )
			
	clearTimeout(g_id_slideshow_timeout)
		
	update_pict_click("user_click")
	send_update_show_clients()
	
	// Set a new time to wait before a slideshow can start.
	g_id_slideshow_timeout = setTimeout(start_slideshow, g_waittime_before_slideshow_start)
	if (g_logging.includes("5"))
			console.log(get_timestamp() + " 5 update_show_clientsEnd. Slideshow starts in " + g_waittime_before_slideshow_start/1000  + " sec, timeout_id: " + g_id_slideshow_timeout + "\n")
}


function fisher_yates_shuffle_array(a) 
{
    var i, t, j
    for (i = a.length - 1; i > 0; i -= 1) {
        t = a[i]
        j = Math.floor(Math.random() * (i + 1))
        a[i] = a[j]
        a[j] = t
    }
}


function save_all_urls()
{
	let url = ""
	for (let member in g_members_display_info) {
		let i = 0
		for (let pict of g_members_display_info[member].pictures) {	
			if (i > 0) 	{	// The signature picture, the very first picture, must not be shown on the big screens
				let club_name = g_members_display_info[member].club_name
				url = "http://" + g_server_address + ":" + g_port_nr + "/" + pict + "?member_fullname=" + member + "&club_name=" + club_name
				g_slideshow_urls.push(url)
			}
			i++
		}
	}
	if (g_logging.includes("3"))
		console.log(get_timestamp() + " 3 \n", g_slideshow_urls)
}


function get_catalog_based_members_display_info() 
{
    let members_display_info = {}
	let member_filename = ""
	let member_dirs = []
	let member_dir = ""
	let dir = ""

	let base_club_dir = "./html/" + g_club_dir
	console.log("base_club_dir: "+base_club_dir)
	
	for (dir of fs.readdirSync(base_club_dir)) {
		member_dir = base_club_dir +"/" + dir
		if (fs.statSync(member_dir).isDirectory()) {
			member_dirs.push(member_dir)	              	
		}
	}
	if (member_dirs.length == 0) {
		console.log("No member directories.")
		process.exit()
	}		
	
	fisher_yates_shuffle_array(member_dirs)  // Get the member directories in random order.
	
	// Create an object with the files per club_member directory.
    for (member_dir of member_dirs) {
		let club_member_display_info = {}
        let pictures = []
		let member_fullname = member_dir.split("/").pop()
		let i = 0
		for (member_filename of fs.readdirSync( member_dir).sort()) {  
			if (member_filename.endsWith(".jpg") || member_filename.endsWith(".JPG") ) {
			
				member_dir = member_dir.replace("./html/", "")  
							
				//  The first file shown on the index page for a member shall be a signature file. A file with the same name as the directory of the member.
				if (i == 0) {
					let member_fi_path = member_dir + "/" + member_fullname + ".jpg"
					pictures.push(member_fi_path)
					i++
				}
				
				// Do not add the signature file twice (and in the wrong place.)
				let sign_fi1 =  member_fullname + ".jpg"
				let sign_fi2 =  member_fullname + ".JPG"
				if ( !(member_filename == sign_fi1 || member_filename == sign_fi2) ) {				
					let member_fi_path = member_dir + "/" + member_filename
					pictures.push(member_fi_path)
				}
			}
		}
		if (pictures.length == 0) {
			console.log(member_dir + " has no pictures.")
			process.exit()
		}
	
		club_member_display_info.club_name = get_club_name(base_club_dir)		
 		club_member_display_info.pictures = pictures
 		club_member_display_info.member_fullname = member_fullname
 		members_display_info[member_fullname] = club_member_display_info
 	}
	
	console.log(members_display_info)

	return (members_display_info)
}


function load_members_display_info()
{	
	g_members_display_info = get_catalog_based_members_display_info()

	save_all_urls()	
	if (g_logging.includes("4")) {
		console.log(get_timestamp() + " 4 \n")
		console.log(g_members_display_info)
	}
		
	init_pict_click()
}	


app.get("/list", function (req, res) {
	if (g_logging.includes("9"))
		console.log(get_timestamp() + " 9 /list")

	load_members_display_info()
	
	res.json(g_members_display_info)
})


app.post("/show", function (req, res) {
	if (g_logging.includes("8"))
		console.log(get_timestamp() + " 8 /show req.body\n", JSON.stringify(req.body))
		
	g_show_url = req.body.url
			
	update_show_clients()
	res.send("SUCCESS")
})


app.get("/show-events", function (req, res) {
	if (g_logging.includes("11"))
		console.log(get_timestamp() + " /show-events OPEN")

	res.setHeader("Content-Type", "text/event-stream")
	res.setHeader("Connection", "keep-alive")

	// Only if reverse-proxy
	res.setHeader("X-Accel-Buffering", "no")

	if (g_logging.includes("10"))
		console.log(get_timestamp() + " 10 /show-events push res")
		
	g_show_clients.push(res)

	res.on("close", function () {
		if (g_logging.includes("11"))	
			console.log(get_timestamp() + " /show-events CLOSE")
		let i = g_show_clients.indexOf(res)
		if (i >= 0)
			g_show_clients.splice(i, 1)
	})

	res.write("retry: 50000\n\n")
	res.write("event: show\n")
	if (g_logging.includes("10"))
		console.log(get_timestamp() + " 10 /show-events g_show_url " + g_show_url)
	
	res.write("data: " + JSON.stringify(g_show_url) + "\n\n")
})
