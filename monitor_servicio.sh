#!/bin/bash

LOGFILE="/var/log/monitor_sistema.log"
INTERVAL=5

# Crear log si no existe
touch "$LOGFILE" || exit 1

# Bucle infinito
while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    echo "===== $TIMESTAMP =====" >> "$LOGFILE"

    ps -eo pid,comm,%cpu,%mem --sort=-%cpu --no-headers \
    | head -n 5 \
    | awk -v ts="$TIMESTAMP" '{printf "%s PID=%s PROC=%s CPU=%s MEM=%s\n", ts, $1, $2, $3, $4}' >> "$LOGFILE"

    echo >> "$LOGFILE"
    sleep "$INTERVAL"
done
