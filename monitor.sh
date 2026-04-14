#!/bin/bash

set -u

if [ $# -lt 1 ]; then
	echo "Uso: $0 \"comando [args]\" [intervalo_segundos]"
	exit 1
fi

CMD="$1"
INTERVAL="${2:-2}"

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || ["$INTERVAL" -le 0 ]; then
	echo "Error: el intervalo debe ser un entero positivo."
	echo "Uso: $0 \"comando [args]\" [intervalo_segundos]"
	exit 1
fi
