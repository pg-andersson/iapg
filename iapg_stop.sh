#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2024 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

fi_tmp1="ps.tmp"
ps ax|grep "node iapg_server.js"|grep -v grep > $fi_tmp1		
while read line ; do
	pid=$(echo ${line} | awk '{print $1}')
	kill ${pid}
	echo "$(date +"%y%m%d-%H%M%S") PID=${pid} killed. ${line}"
done < $fi_tmp1
rm -f ${fi_tmp1}

bash click_stats_to_csv.sh

