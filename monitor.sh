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


PID=""
LOGFILE=""
PNGFILE=""
DATAFILE=""
START_EPOCH=""

# Función
generar_grafica() {
    # Si no existe log o está vacío, no se grafica
    if [ ! -f "$LOGFILE" ] || [ ! -s "$LOGFILE" ]; then
        echo "No hay datos en el log para graficar."
        return
    fi

    DATAFILE="monitor_${PID}.dat"
    PNGFILE="monitor_${PID}.png"

    # Convertir log a datos: tiempo_transcurrido cpu rss
    awk '
    BEGIN {
        first = 0
    }
    {
        # Formato esperado:
        # YYYY-MM-DD HH:MM:SS CPU MEM RSS
        timestamp = $1 " " $2
        cpu = $3
        mem = $4
        rss = $5

        # Convertir timestamp a epoch usando mktime()
        split($1, d, "-")
        split($2, t, ":")

        epoch = mktime(d[1] " " d[2] " " d[3] " " t[1] " " t[2] " " t[3])

        if (first == 0) {
            first = epoch
        }

        elapsed = epoch - first

        # Salida: tiempo cpu mem rss
        print elapsed, cpu, mem, rss
    }
    ' "$LOGFILE" > "$DATAFILE"

    # Generar script temporal de gnuplot
    GNUPLOT_SCRIPT=$(mktemp)

    cat > "$GNUPLOT_SCRIPT" <<EOF
set terminal pngcairo size 1200,600
set output "${PNGFILE}"

set title "Monitoreo: ${CMD} (PID ${PID})"
set xlabel "Tiempo transcurrido (s)"
set ylabel "CPU (%)"
set y2label "Memoria RSS (KB)"
set y2tics
set grid
set key outside

plot "${DATAFILE}" using 1:2 with lines lw 2 title "CPU (%)" axes x1y1, \
     "${DATAFILE}" using 1:4 with lines lw 2 title "RSS (KB)" axes x1y2
EOF

    if command -v gnuplot >/dev/null 2>&1; then
        gnuplot "$GNUPLOT_SCRIPT"
        echo "Gráfica generada: ${PNGFILE}"
    else
        echo "Advertencia: gnuplot no está instalado. No se pudo generar la gráfica."
    fi

    rm -f "$GNUPLOT_SCRIPT"
}


manejar_sigint() {
    echo
    echo "Interrupción detectada (Ctrl+C)."

    if [ -n "${PID}" ] && kill -0 "$PID" 2>/dev/null; then
        echo "Enviando SIGTERM al proceso monitorizado (PID ${PID})..."
        kill -TERM "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi

    generar_grafica
    exit 0
}

trap manejar_sigint SIGINT

# Ejecucion
bash -c "$CMD" &
PID=$!

LOGFILE="monitor_${PID}.log"
PNGFILE="monitor_${PID}.png"

echo "Proceso lanzado."
echo "Comando : $CMD"
echo "PID     : $PID"
echo "Intervalo: ${INTERVAL}s"
echo "Log     : $LOGFILE"

START_EPOCH=$(date +%s)

# Registro
while kill -0 "$PID" 2>/dev/null; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # ps devuelve: %cpu %mem rss
    read -r CPU MEM RSS <<< "$(ps -p "$PID" -o %cpu,%mem,rss --no-headers 2>/dev/null | awk '{print $1, $2, $3}')"

    # Si el proceso terminó justo entre kill y ps, salir del ciclo
    if [ -z "${CPU:-}" ] || [ -z "${MEM:-}" ] || [ -z "${RSS:-}" ]; then
        break
    fi

    echo "$TIMESTAMP $CPU $MEM $RSS" >> "$LOGFILE"
    sleep "$INTERVAL"
done

# Esperar al proceso por limpieza
wait "$PID" 2>/dev/null

# Graficación 
generar_grafica

echo "Monitoreo finalizado."
echo "Archivo log : $LOGFILE"
echo "Archivo PNG : $PNGFILE"
