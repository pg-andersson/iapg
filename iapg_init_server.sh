#!/bin/bash  
# This file is part of iapg (Interactive Photo Gallery).
# Copyright (C) 2025 PG Andersson <pg.andersson@gmail.com>.
# iapg is free software: you can redistribute it and/or modify it under the terms of GPL-3.0-or-later

# This script it is started by systemd iapg_init_server.service. Its sole purpose is to start the long running iapg_server_starter.sh control program.
# Forking in a systemd service must be done in a program that has a short life.  
# systemd can therefore not start iapg_server_starter.sh directly. It would have failed with "timed out".
# By letting systemd "fork" iapg_init_server.sh which in turn "fork" iapg_server_starter.sh the latter will not be terminated by systemd.
 
g_bash=$(which "bash")
g_base=$HOME/iapg-main

suff=$(date +%Y-%m-%d_%H-%M-%S)
fi_log=${g_base}"/var/log/iapg_server_starter_stdout_err_"${suff}".log"

$g_bash ${g_base}/iapg_server_starter.sh > ${fi_log} 2>&1 &


