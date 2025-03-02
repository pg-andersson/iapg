#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

# This script it is started by systemd iapg_init_kiosk.service. Its sole purpose is to start the long running iapg_kiosk.sh control program.
 
g_bash=$(which "bash")

g_base=$HOME/iapg-main

suff=$(date +%Y-%m-%d_%H-%M-%S)
fi_log=${g_base}"/var/log/iapg_kiosk_stdout_err_"${suff}".log"

g_fi_log=${g_base}"/var/log/iapg_init_kiosk_"${suff}".log"
source ${g_base}/iapg_functions.sh

logit "Just started by systemd. Will sleep 2s"
sleep 2	
logit "Slept 2s. Will now start iapg_kiosk.sh" 
$g_bash ${g_base}/iapg_kiosk.sh > ${fi_log} 2>&1 &

logit "Started iapg_kiosk.sh. Will exit now."
