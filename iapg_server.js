// This file is part of iapg (Interactive Photo Gallery).
// Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
// iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

// This javascript serves tablets with thumbnails and the kiosks with pictures.

"use strict"

let g_logging = "0"		// Documented in iapg_server.conf 

const fs = require("fs")
const http = require("http")
const express = require("express")
const os = require('os');
const process = require('process');
const sqlite3 = require("better-sqlite3")
const sharp = require("sharp")

const g_base = os.homedir() + "/iapg-main" 
const g_etc_dir = g_base + "/etc"
const g_html_dir = g_base + "/html"
const g_var_dir = g_base + "/var"
const g_log_dir = g_var_dir + "/log"
const g_stat_dir = g_var_dir + "/stat"
const g_fi_conf = g_etc_dir + "/iapg_server.conf"

let g_club_dir
let g_port_nr
let g_photographer_blocks_pos_on_tablets_randomized
let g_waittime_before_slideshow_start =  1*60000
let g_pict_displaytime_slideshow =  10*1000
let g_show_kiosk_ip_as_footer = 0

let display_nr_action_lines = 10
let g_log_rec = ""

console.log("Platform: " + os.platform())
console.log("homedir: " + g_base)

get_arg()	
const g_fi_status = g_log_dir + "/actions_server_" + g_club_dir + "_" + g_port_nr
const g_fi_member_dir_error = g_log_dir + "/a_member_dir_error_" + g_club_dir + "_" + g_port_nr
const g_fi_active_kiosks = g_log_dir + "/active_kiosks_" + g_club_dir + "_" + g_port_nr

get_server_conf()
console.log("listen on port:" + g_port_nr)
console.log("waittime_before_slideshow_start= ", g_waittime_before_slideshow_start)
console.log("pict_displaytime_slideshow= ", g_pict_displaytime_slideshow)

const g_fi_clicks = g_stat_dir + "/" + get_date() + "_clicks_" + g_port_nr + ".json"
const g_fi_click_ports = g_stat_dir + "/clicks_" + g_port_nr + "_" + get_timestamp(false) + ".json"

clean_clubdirs_from_apple_turd() 

if (fs.existsSync(g_fi_member_dir_error)) {
	fs.unlinkSync(g_fi_member_dir_error) 
	console.log("Deleted: " + g_fi_member_dir_error)							
}

var app = express()
app.use(express.static('./html'))
app.use(express.urlencoded({ extended: false }))
http.createServer(app).listen(g_port_nr)

var db = new sqlite3("./var/thumbnails.db")
create_thumbnails_table()
var select_thumb_stm = db.prepare("SELECT thumb FROM thumbnails WHERE path = ?")
var insert_thumb_stm = db.prepare("INSERT OR IGNORE INTO thumbnails (path,thumb) VALUES ( ?, ? )")
var delete_thumb_stm = db.prepare("DELETE FROM thumbnails WHERE path = ( ? )")

cleanup_thumbnail_cache()

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
load_members_display_info()	// Must reload the display_info in case the iapg_server gets restarted while the control tablet still has an index page.

start_slideshow("none")			// Let the slideshow run to start with.


function get_arg()
{
	if (process.argv.length !== 5) {
		console.log("Invalid arguments: club_dir port_nr sort-order")
		process.exit()
	}
	
	g_club_dir = process.argv[2]	
	g_port_nr = process.argv[3]
	g_photographer_blocks_pos_on_tablets_randomized = process.argv[4]
}


function log_member_dir_error(txt, also_console_log)
{
	var log_rec = get_timestamp(true) + " " + txt

	if (also_console_log) 
		console.log(log_rec)
		
	fs.writeFileSync(g_fi_member_dir_error, log_rec)	
}


function log_status(txt, also_console_log)
{
	var start_ix_write = 0
	var i = 0
	var actions_len = 0
	let actions = []
	let upd_actions = ""

	var log_rec = get_timestamp(true) + " " + txt

	if (also_console_log) 
		console.log(log_rec)
		
	if (fs.existsSync(g_fi_status)) {
		var data = fs.readFileSync(g_fi_status, 'utf8').toString()
		actions = data.split('\n')
	}
	
	actions.push(log_rec)	              	
	actions_len = actions.length

	if (actions_len > display_nr_action_lines) {
		start_ix_write = actions_len - display_nr_action_lines
	} else {
		start_ix_write = 0
	}		
			
	for (i = start_ix_write; i < actions_len;  i++ ) {
		if (actions[i] != "" )
			upd_actions = upd_actions + actions[i] + "\n"
	}

	fs.writeFileSync(g_fi_status, upd_actions)	
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


function get_date()
{
	const d = new Date()
	let tmp = d.toLocaleString("sv")
	tmp = tmp.split(" ")
	return(tmp[0])
}


function get_server_address() 
{
	let server_address_v4 = ""
	let server_address_v6 = ""
	let networkInterfaces = os.networkInterfaces();

	console.log(os.networkInterfaces())
	
	for (let netint in networkInterfaces) {
		for (let iface of networkInterfaces[netint]) {
			g_log_rec = "1 networkInterfaces, iface.family:\n" + iface.family
			log_status(g_log_rec, g_logging.includes("1"))
			if (iface.family == "IPv4") {
				server_address_v4 = iface.address
				g_log_rec =  " 1 iface.address:\n" + server_address_v4
				log_status(g_log_rec, g_logging.includes("1"))
			}
			if (iface.family == "IPv6") {
				server_address_v6 = iface.address
				g_log_rec =  " 1 iface.address:\n" + server_address_v6
				log_status(g_log_rec, g_logging.includes("1"))
			}
		}
	}

	g_log_rec = "1 addresses:\n" + "v4: " + server_address_v4 + " v6: " + server_address_v6
	log_status(g_log_rec, g_logging.includes("1"))

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
				g_log_rec = "2 config file:"
				log_status(g_log_rec, g_logging.includes("2"))
				if (g_logging.includes("3")) {
					console.log(params)
				}
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
			if (param.startsWith("show_kiosk_ip_as_footer")) {
				val = param.split('=').pop()
				//val = val.trim()
				g_show_kiosk_ip_as_footer = val
			}			
		}
	} catch (err) {
		console.error(err)
	}
}


function create_thumbnails_table()
{
	db.exec(` CREATE TABLE IF NOT EXISTS thumbnails (
		path TEXT PRIMARY KEY,
		thumb BLOB) `)
}


function cleanup_thumbnail_cache()
{
	var stmt = db.prepare("SELECT path FROM thumbnails")
	var cached = stmt.all()	
	let fi = ""
	let len = cached.length
	for (let i=0; i < len; i++ ) {
		fi = cached[i].path
		if (!fs.existsSync(fi)) {
			console.log("Only in the cache, deletes it now: "+fi)
			delete_thumb_stm.run(fi)			
		}
	}
}


async function get_thumb(path) {
	g_log_rec =  "4b BEG: get_thumb pict:" + path
	log_status(g_log_rec, g_logging.includes("5"))
	let pict = path
	var row = select_thumb_stm.get(pict)
	if (!row) {
		var new_thumb = await sharp(pict).resize(170, null).jpeg({quality: 90}).toBuffer()		
		insert_thumb_stm.run(pict, new_thumb)
		g_log_rec =  "4b END: get_thumb Create and insert pict:" + pict
		log_status(g_log_rec, g_logging.includes("5"))
		return new_thumb
	} else {
		g_log_rec =  "4b END: get_thumb Found cached pict:" + pict
		log_status(g_log_rec, g_logging.includes("5"))
		return row.thumb
	}
}


function get_club_name()
{
	// Get the club's name from club_name.txt  /home/fg/iapg-main/var/club-1_club_name.txt
	let club_name = g_club_dir
	let fi_club = g_var_dir + "/" + g_club_dir + "_club_name.txt"
	try {
		var data = fs.readFileSync(fi_club, 'utf8').toString();
		club_name = data.trim()		
	} catch (err) {
		club_name = g_club_dir
	}
	console.log(club_name)
	return(club_name)
}


function clean_clubdirs_from_apple_turd() 
{
	
	let club_dirs = fs.readdirSync(g_html_dir)
	for (let club_dir of club_dirs) {
		let full_path = g_html_dir + "/" + club_dir
		if (fs.statSync(full_path).isDirectory()) {
			if (club_dir.startsWith("club-")) {
				let memb_dirs = fs.readdirSync(full_path)
				for (let memb_dir of memb_dirs) {
					full_path = g_html_dir + "/" + club_dir + "/" + memb_dir
					if (fs.statSync(full_path).isDirectory()) {
						let memb_files = fs.readdirSync(full_path)
						for (let memb_file of memb_files) {
								if (memb_file.startsWith("._")) { 
									full_path = g_html_dir + "/" + club_dir + "/" + memb_dir + "/" + memb_file
									fs.unlinkSync(full_path) 
									console.log("Deleted: " + full_path)							
							}
						}
					}
				}		
			}
		}
	}
}


function init_pict_click()
{
	// Click stats per club_member.
	for (let member in g_members_display_info) {
		let member_click_stats = {}
		let member_picts_info = []
		for (let picture of g_members_display_info[member].pictures) {	
			let pict_info = {}					

			pict_info.pict = picture.split('/').pop()	// pictures/A Andersson/A good picture.jpg?member_fullname=A Andersson&club_name=xyz
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
	// pictures/A Andersson/A good picture.jpg?member_fullname=A Andersson&club_name=xyz
	let q = g_show_url.split("?")	
	let pict = q[0].split("/").pop()
	let a = q[1].split("&")
	let member = a[0].split("=").pop()
	let club_name = a[1].split("=").pop()

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
			g_click_stats[member].picts_info[ix].first_userclick = get_timestamp(false)
		}
		g_click_stats[member].picts_info[ix].last_userclick = get_timestamp(false) 
	} else {
		g_click_stats[member].picts_info[ix].nr_slideshows++ 
		if (g_click_stats[member].picts_info[ix].first_slideshow == "") {
			g_click_stats[member].picts_info[ix].first_slideshow = get_timestamp(false)
		}
		g_click_stats[member].picts_info[ix].last_slideshow = get_timestamp(false) 
	}
	fs.writeFileSync(g_fi_click_ports, JSON.stringify(g_click_stats, 0, 4))
}


function send_update_show_clients(ip, req_type)
{
	let s = req_type + ": Last_thumb_click_tablet_IP:" +ip
	
	g_log_rec = "10 BEG send_update_show_clients " + s + " show_url"
	log_status(g_log_rec, g_logging.includes("10"))
	
	let i = 1
	let log_rec = ""
	let res_ip = ""
	let req = ""
	let res = ""
	let kiosk_a = ""
	let orig_g_show_url = g_show_url
	for (let reqres of g_show_clients) {
		req = reqres.request
		res = reqres.response
		res_ip = " kiosk_IP:" + req.ip
		res.write("event: show\n")

		if (g_show_kiosk_ip_as_footer == 1) {
			s = req.ip.split(":")	// ipv6 ipv4
			kiosk_a = s[3]
			g_show_url = orig_g_show_url + "&my_ip=" + kiosk_a + " " + g_port_nr + " " + g_club_dir 
		} else {
			g_show_url = orig_g_show_url + "&my_ip=none"
		}
		
		res.write("data: " + JSON.stringify(g_show_url) + "\n\n")
		g_log_rec = "10 MID: send_update_show_clients ix_kiosk=" + i + res_ip + " write event: show, data: " + JSON.stringify(g_show_url)
		log_status(g_log_rec, g_logging.includes("10"))
		log_rec = log_rec + get_timestamp(true) + " kiosk=" + i + " " + reqres.request.ip + "#"
		i = i + 1
	}
	fs.writeFileSync(g_fi_active_kiosks, log_rec)	
	g_log_rec = "10 END send_update_show_clients "
	log_status(g_log_rec, g_logging.includes("10"))

}


function start_slideshow(ip)
{	
	let	s = "Last_thumb_click_tablet_IP:"+ip	

	g_log_rec = "9 BEG start_slideshow " + s + " ix_pict: " + g_next_slide_to_show	
	log_status(g_log_rec, g_logging.includes("9"))
				
	g_show_url = g_slideshow_urls[g_next_slide_to_show]
	update_pict_click("slideshow")
	send_update_show_clients(ip, "slideshow")

	g_next_slide_to_show++
	if ( g_next_slide_to_show == g_slideshow_urls.length)
		g_next_slide_to_show = 0	
		
	// Set a time to wait before the next slide is sent.
	g_id_slideshow_timeout = setTimeout(start_slideshow, g_pict_displaytime_slideshow, ip)
	g_log_rec = "9 END start_slideshow " + s  + " Next in: " + g_pict_displaytime_slideshow/1000 + " sec, timeout_id: " + g_id_slideshow_timeout
	log_status(g_log_rec, g_logging.includes("9"))

}


function update_show_clients(req) 
{
	g_log_rec = "8 BEG update_show_clients Last_thumb_click_tablet_IP :" + req.ip + " clearTimeout id: " + g_id_slideshow_timeout
	log_status(g_log_rec, g_logging.includes("8"))
			
	clearTimeout(g_id_slideshow_timeout)
		
	update_pict_click("user_click")
	send_update_show_clients(req.ip, "user_click")
	
	// Set a new time to wait before a slideshow can start.
	g_id_slideshow_timeout = setTimeout(start_slideshow, g_waittime_before_slideshow_start, req.ip)
	g_log_rec = "8 END update_show_clients Last_thumb_click_tablet_IP: " + req.ip + " setTimeout Slideshow starts in: " + g_waittime_before_slideshow_start/1000  + " sec, timeout_id: " + g_id_slideshow_timeout
	log_status(g_log_rec, g_logging.includes("8"))
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
	g_log_rec = "3 BEG: save_all_urls slideshow_urls:"
	log_status(g_log_rec, g_logging.includes("3"))
	g_slideshow_urls = []
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
	if (g_logging.includes("3")) {
		console.log(g_slideshow_urls)
	}
	g_log_rec = "3 END: save_all_urls slideshow_urls"
	log_status(g_log_rec, g_logging.includes("3"))
}


function get_catalog_based_members_display_info() 
{
	let members_display_info = {}
	let member_filename = ""
	let member_dirs = []
	let member_dir = ""
	let dir = ""
	let full_member_dir = ""

	let base_club_dir = g_html_dir + "/" + g_club_dir
	console.log("base_club_dir: " + base_club_dir)
	
	for (dir of fs.readdirSync(base_club_dir)) {
		member_dir = base_club_dir + "/" + dir
		if (fs.statSync(member_dir).isDirectory()) {
			member_dirs.push(member_dir)	              	
		}
	}
	if (member_dirs.length == 0) {
		log_member_dir_error("No member directories in " + base_club_dir , true)
		process.exit()
	}		
	
	if (g_photographer_blocks_pos_on_tablets_randomized == "r")
		fisher_yates_shuffle_array(member_dirs)  // Get the member directories in random order.
		
	// Create an object with the files per club_member directory.
    for (member_dir of member_dirs) {
		let club_member_display_info = {}
        let pictures = []
		let member_fullname = member_dir.split("/").pop()
		let i = 0
		for (member_filename of fs.readdirSync( member_dir).sort()) {  
			if (member_filename.endsWith(".jpg") || member_filename.endsWith(".JPG") ) {			
				//  Variant A member_dir = member_dir.replace(g_html_dir + "/", "")  
				//  Variant B member_dir = member_dir.replace("./html/", "")  
				full_member_dir = member_dir
				member_dir = member_dir.replace(g_html_dir + "/", "")  
							
				//  The first file shown on the index page for a member shall be a signature file. A file with the same name as the directory of the member.
				if (i == 0) {
					let member_fi_path = member_dir + "/" + member_fullname + ".jpg"
					full_member_dir = full_member_dir + "/" + member_fullname + ".jpg"
					if (!fs.existsSync(full_member_dir)) {
						log_member_dir_error("No signature-file with the name of the member is found. Wanted: " + full_member_dir , true)
						process.exit()
					}										
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
			log_member_dir_error("No pictures in " + member_dir , true)
			process.exit()
		}
	
		club_member_display_info.club_name = get_club_name()		
 		club_member_display_info.pictures = pictures
 		club_member_display_info.member_fullname = member_fullname
 		members_display_info[member_fullname] = club_member_display_info
 	}
	
	return (members_display_info)
}


function load_members_display_info()
{	
	g_members_display_info = get_catalog_based_members_display_info()

	save_all_urls()	
	g_log_rec =  "5 BEG: load_members_display_info members_display_info:" 
	log_status(g_log_rec, g_logging.includes("5"))
	if (g_logging.includes("5")) {
		console.log(g_members_display_info)
	}
	g_log_rec =  "5 END: load_members_display_info members_display_info:" 
	log_status(g_log_rec, g_logging.includes("5"))

	init_pict_click()
}	


app.get("/list", function (req, res) {
	g_log_rec = "4 BEG: app.get /list, IP: " + req.ip 
	log_status(g_log_rec, g_logging.includes("4"))

	load_members_display_info()	

	g_log_rec = "4 END: app.get /list "
	log_status(g_log_rec, g_logging.includes("4"))
	
	res.json(g_members_display_info)								 
})


app.get("/thumb", async function (req, res) {
	g_log_rec =  "4a app.get /thumb IP: " + req.ip + " path: " + req.query.pict
	log_status(g_log_rec, g_logging.includes("4"))
	
	var s = req.query.pict			
	var pict = s.split("?")[0]	
	var path_to_image_on_disk = "./html/" + pict
	// index.html img.src = "/thumb?pict=" + pict + "?member_fullname=" + member_fullname

	var thumb_blob = await get_thumb(path_to_image_on_disk) // sharp, sqlite create and get thumbnail
	
	res.type("image/jpeg").send(thumb_blob) 
})


app.post("/show", function (req, res) {
	g_log_rec =  "6 /show, IP: " + req.ip + " req.body:\n" + JSON.stringify(req.body)	
	log_status(g_log_rec, g_logging.includes("6"))

	g_show_url = req.body.url + "&club_name=" + req.body.club_name
			
	update_show_clients(req)
	res.send("SUCCESS")
})


app.get("/show-events", function (req, res) {
	g_log_rec = "7 /show-events OPEN, IP: " + req.ip
	log_status(g_log_rec, g_logging.includes("7"))

	res.setHeader("Content-Type", "text/event-stream")
	res.setHeader("Connection", "keep-alive")

	// Only if reverse-proxy
	res.setHeader("X-Accel-Buffering", "no")

	g_log_rec = "7 /show-events push, IP: " + req.ip
	log_status(g_log_rec, g_logging.includes("7"))
	
	g_show_clients.push({ request: req, response: res })

	res.on("close", function () {
		g_log_rec = "7 /show-events CLOSE, IP: " + req.ip
		log_status(g_log_rec, g_logging.includes("7"))

		let i = 0
		for (let reqres of g_show_clients) {
			if (reqres.response == res) {	
				// Shall not get any more picts
				g_show_clients.splice(i, 1)	
				g_log_rec = "7 /show-events CLOSE, removed kiosk at ix: " + i + " IP: " + req.ip
				log_status(g_log_rec, g_logging.includes("7"))
				break
			}
			i++
		}
	})

	res.write("retry: 50000\n\n")
	res.write("event: show\n")
	g_log_rec = "7 /show-events, IP: " + req.ip + " g_show_url:\n" + g_show_url
	log_status(g_log_rec, g_logging.includes("7"))
	
	res.write("data: " + JSON.stringify(g_show_url) + "\n\n")
})
