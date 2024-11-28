#!/bin/bash

# Variables globales
mlog="/var/log/mlog.log"
LOCKFILE="/tmp/mlogger.lock"
# En caso de que se activen los avisos por mail :)
#mail= 

# ---------- COMIENZO DEL SCRIPT ----------

# Enviar mails en caso de urgencia
function mlogmail() {
# Para usar esta función introducimos un asunto más un mensaje y luego llamamos a la función con estas variables
    local asunto=$1
    local mensaje=$2
# Ejemplo de uso asunto="CRIT" mensaje="Tacho nene el server" mlogmail "$asunto" "$mensaje"
    echo -e "Subject: $asunto\n\n$mensaje" | msmtp $mail
}

# Imprimir delimitadores
function mlogdelimit {
    local del=$1
    local num=$2
    printf '%*s\n' $num | tr ' ' "$del"
    # Uso: mlgdelimit '*_-#' 50
}

# Función para agregar la hora al log
function mlogtime() {
    mlogdelimit '_' 100 >> "$mlog"
    echo >> "$mlog"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$mlog"
}

# Función para 'Flaggear' los eventos que van al logger
function mloggerflags {
    local nivel=$1
    local flag=$2

    case "$nivel" in
        0) logger -p user.emerg "$flag";; 	# Pánico en el sistema
        1) logger -p user.alert "$flag";; 	# Alerta
        2) logger -p user.crit "$flag";; 	# Crítico
        3) logger -p user.err "$flag";; 	# Error
        4) logger -p user.warning "$flag";; 	# Advertencia
        5) logger -p user.notice "$flag";; 	# Aviso
        6) logger -p user.info "$flag";; 	# Información
        7) logger -p user.debug "$flag";; 	# Depuración
    esac
}


# Diccionario de servicios
# Uso: [service]=[0-2]
declare -A servcatlog=(
    [cron]=0
    [rsyslog]=0
    [systemd-journald]=0
    [bind9]=0
    [kea-dhcp4-server]=0
    [ufw]=0
    [apparmor]=1
    [snapd]=2
    [cups]=2
)

# Diccionario de archivos de registros
declare -A logfiles=(
    ["/var/log/syslog"]="error",
    ["/var/log/auth.log"]="failed password",
    ["/var/log/kern.log"]="error",
    ["/var/log/apt/history.log"]="error",
    ["/var/log/daemon.log"]="error",
    ["/var/log/mysql/error.log"]="error",
    ["/var/log/ufw.log"]="BLOCK",
    ["/var/log/mail.log"]="error",
    ["/var/log/apache2/error.log"]="error",
    ["/var/log/cron.log"]="error",
    ["/var/log/boot.log"]="error",
    ["/var/log/dmesg"]="*error*"
)

# Asegurarse de que el archivo de log existe
function logfile {
    if [[ ! -e "$mlog" ]]; then
        touch "$mlog" || { echo "Error al crear el archivo de log"; exit 1; }
    fi
}

# Elimina el LOCKFILE si existe al iniciar el script (por si el servicio fue detenido previamente)
if [[ -e "$LOCKFILE" ]]; then
    rm -f "$LOCKFILE"
fi

# Crea el LOCKFILE y define la trampa para eliminarlo al salir
touch "$LOCKFILE"
trap 'rm -f $LOCKFILE; exit' EXIT SIGINT SIGTERM


# ---------- COMIENZO DEL SCRIPT DE MONITOREO ----------

# Función para verificar la conexión a internet cada 15 minutos
function connection {
    ping -c 4 8.8.8.8 >> /dev/null
    if [[ $? -ne 0 ]]; then
        mloggerflags 2 "CRITICAL: El servidor no tiene conexión a internet, por favor revise el servidor"
    else
        mlogtime "El servidor tiene conexión a internet"
    fi
}

# Función para monitorear el uso de la CPU
function CPUsage {
    # Leer la línea de /proc/stat y almacenar los valores relevantes
    cpu_stats_old=$(awk '{print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)
    
    # Esperar un segundo
    sleep 1

    # Leer nuevamente los valores de /proc/stat
    cpu_stats_new=$(awk '{print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)

    # Extraer el uso total y el tiempo inactivo de ambas lecturas
    read cpu_total_old cpu_idle_old <<< $cpu_stats_old
    read cpu_total_new cpu_idle_new <<< $cpu_stats_new

    # Calcular el uso de CPU
    cpu_diff=$((cpu_total_new - cpu_total_old))
    idle_diff=$((cpu_idle_new - cpu_idle_old))
    cpu_usage=$((100 * (cpu_diff - idle_diff) / cpu_diff))

    if [[ $cpu_usage -gt 90 ]]; then
    # Avisar por email
    	asunto="EVENTO CRÍTICO: USO DE CPU"
     	mensaje="El uso de la CPU ha sobrepasado el límite del 90%, ve cagando leches"
      	mlogmail "$asunto" "$mensaje"
       
    # Avisar por syslog 
        mloggerflags 1 "ALERTA: El uso de la CPU ha sobrepasado el 90%, por favor revise el servidor"
    elif [[ $cpu_usage -gt 80 ]]; then
        mlogtime "WARNING: El uso de la CPU ha sobrepasado el 80%"
    fi
}

# Función para monitorear el uso de la RAM
function RAMUsage {
    # Obtener la información de memoria en MB
    mem_info=$(free -m | grep Mem: | awk '{print $2, $3, $4}')
    read total_memory_mb used_memory_mb free_memory_mb <<< $mem_info

    # Calcular el porcentaje de uso de la RAM
    ram_usage=$((100 * used_memory_mb / total_memory_mb))

    if [[ $ram_usage -gt 90 ]]; then
    # Avisar por mail
    asunto="ERROR CRÍTICO: USO DE RAM"
    mensaje="El uso de la RAM ha sobrepasado el límite del 90%, ve cagando leches"
    mlogmail "$asunto" "$mensaje"
       
    # Avisar por syslog
        mloggerflags 1 "ALERT: El uso de la memoria ha superado el 90%!!"
    elif [[ $ram_usage -gt 80 ]]; then
        mlogtime "WARNING: El uso de la memoria ha superado el 80%"
    fi
}

# Función para monitorear el almacenamiento del disco
function DiskUsage {
    df -h | grep -E '^/dev/' | awk '{print $1 " " $5}' | while read line; do
        partition=$(echo $line | awk '{print $1}')
        usage=$(echo $line | awk '{print $2}' | sed 's/%//')
        if [[ ! -z "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
            if [[ $usage -gt 95 ]]; then
	    # Avisar por mail
    	    	asunto="PROBLEMA DE ALMACENAMIENTO: ALMACENAMIENTO COLAPSADO"
            	mensaje="El disco duro ha sobrepasado el índice del 95%, VE ECHANDO RAYOS"
            	mlogmail "$asunto" "$mensaje"
	     
	    # Avisar por syslog
                mloggerflags 0 "PANIC: El uso del disco en $partition ha sobrepasado el 95%, por favor revise el servidor"
            elif [[ $usage -gt 90 ]]; then
	    # Avisar por mail
    	    	asunto="PROBLEMA DE ALMACENAMIENTO: ALMACENAMIENTO CASI LLENO"
            	mensaje="El disco duro ha sobrepasado el índice del 90%, revisar urgente"
            	mlogmail "$asunto" "$mensaje"
	     
	    # Avisar por syslog
                mloggerflags 1 "ALERT: El uso del disco en $partition ha sobrepasado el 90%, por favor revise el servidor"
            elif [[ $usage -gt 80 ]]; then
                mlogtime "WARNING: El uso del disco en $partition ha sobrepasado el 80%"
            fi
        else
            echo "Error: Valor de uso de disco no válido para la partición $partition"
        fi
    done
}

# Función para verificar los servicios críticos
function checkCritSrvcs {

    active_services=()  # Reiniciar el array de servicios activos

    for service in "${!servcatlog[@]}"; do
        level="${servcatlog[$service]}"
        echo "DEBUG: Verificando servicio $service (nivel $level)"

        if ! systemctl show "$service" --no-pager > /dev/null 2>&1; then
            mlogtime "INFO: El servicio $service no está instalado o no se puede verificar."
            continue
        fi

        if systemctl is-active --quiet "$service"; then
            active_services+=("$service")
            echo "DEBUG: $service está activo."
        else
            echo "DEBUG: $service está detenido. Procesando según criticidad ($level)."
            case "$level" in
                0)
                    mloggerflags 0 "CRITICAL: El servicio $service está detenido o fallando."
                    asunto="SERVICIO CRÍTICO FALLANDO"
                    mensaje="El servicio $service está caído o fallando. Acuda al servidor."
                    mlogmail "$asunto" "$mensaje"
                    ;;
                1)
                    mloggerflags 1 "ALERT: El servicio $service no está activo."
                    ;;
                2)
                    mlogtime "WARNING: El servicio $service no está activo."
                    ;;
            esac
        fi
    done

    if [[ ${#active_services[@]} -gt 0 ]]; then
        mlogtime "SUCCESS: Los servicios ${active_services[*]} están activos y funcionando correctamente."
    fi
}

# Función para monitorear errores en los logs
function checklogs {
    for log in "${!logfiles[@]}"; do
        echo "Buscando errores en ${log##*/}..."
        if [[ -f "$log" ]]; then
            # Buscar errores solo en las últimas 100 líneas para mejorar eficiencia
            errors=$(tail -n 25 "$log" | grep -i "${logfiles[$log]}")
            if [[ -n "$errors" ]]; then
                mlogtime "Errores en ${log##*/}"
                echo "$errors" >> "$mlog"
                mloggerflags 3 "Errores encontrados en ${log##*/}: $errors"
            fi
        else
            continue
        fi
    done
}

# Función para mostrar el uso de la swap
function swapusage {
    fswap=$(free -m | awk ' NR==3 {print $2}')
    uswap=$(free -m | awk ' NR==3 {print $3}')
    pswap=$(echo "scale=2; ($uswap / $fswap) * 100" | bc)

    if (( $(echo "$pswap >= 90" | bc -l) )); then
        mloggerflags 1 "ALERTA: El uso de la memoria swap ha alcanzado el 90%"
    elif (( $(echo "$pswap >= 80" | bc -l) )); then
        mlogtime "CRITICAL: El uso de la memoria swap ha alcanzado el 80%"
    fi
}

# Función para obtener los procesos más "Contaminantes para el sistema" (Que mayor carga generan)
function gethighprocess {
    ghpc=$(ps -eo pid,ppid,cmd,%cpu,%mem,time --sort=-%cpu | head -n 10)
    ghpm=$(ps -eo pid,ppid,cmd,%cpu,%mem,time --sort=-%mem | head -n 10)

    # Generar tabla
    header="%-8s %-8s %-25s %-4s %-4s %-10s\n"
{
    mlogtime "Procesos con más uso de recursos (Order by CPU)"
    printf "$header" "   PID" "  PPID" "PROCESO" " CPU" " RAM" "TIEMPO"
    printf "%0.s-" {1..70}
    echo
    echo "$ghpc" | tail -n +2

} >> "$mlog"
}

# Función para obtener el uso de la red
function netusage {
    checknet=$(ifstat -t 1 5)
    mlogtime "Estadísticas del uso de red (5 segundos atrás)"
    echo "$checknet" >> "$mlog"
}

# Función para obtener conexiones entrantes y salientes con netstat o ss
function getconnections {
    getconnections=$(netstat -tulnp)
    regs="/etc/mlogger/regs"
    reg="$regs/netstat-$(date +'%Y%m%d_%H%M%S').log"

    # Si no existe el directorio lo crea
    if [ ! -d "$regs" ]; then 
        mkdir -p "$regs"    
    fi

    {
        echo "=== Registro de conexiones - $(date '+%Y-%m-%d %H:%M:%S') ==="; echo
        echo "$getconnections"
    } > "$reg"  # Redirigimos la salida al archivo de registro

    mlogtime "Registro de conexiones entrantes y salientes realizado y guardado en $regs"
}

# Función para obtener un mini registro de los puertos en uso 
function openports {
    # Ejecutamos el comando nmap para escanear puertos
    sopenports=$(nmap -sS -sU -p- localhost | sed -n '/PORT/,/Nmap scan report/{/Nmap scan report/!p}')

    # Definimos el directorio de registros y el archivo de registro con la fecha
    regs="/etc/mlogger/regs"
    reg="$regs/openports-$(date +'%Y%m%d_%H%M%S').log"

    # Verificamos si el directorio existe y lo creamos si no existe
    if [ ! -d "$regs" ]; then
        mkdir -p "$regs"  # Si no existe el directorio, lo creamos
    fi

    # Guardamos la salida de nmap en el archivo de registro con la fecha y hora
    {
        echo "=== Registro de escaneo de puertos - $(date '+%Y-%m-%d %H:%M:%S') ==="; echo
        echo "$sopenports"
    } > "$reg"  # Redirigimos la salida al archivo de registro

    # Guardamos un mensaje de registro (sin mostrarlo en pantalla)
    mlogtime "Escaneo de puertos y servicios realizado y guardado en $reg"
}


# Función que verifica si el cronjob de las copias de seguridad esta "vivo"
function checkbackupscron {
    cronjobmlogger="/etc/cron.d/mloggerbackups-cron"
    if ! grep -q "$cronjobmlogger"; then 
        mlogtime "El cronjob de las copias de seguridad no está o no se ha instalado"
    else 
        mlogtime "El cronjob de las copias de seguridad está activo"
    fi
}

# Función para monitorear el tiempo activo del sistema
function servuptimeuser {
    uptimeInfo=$(uptime -p)

    # Extraemos días, horas y minutos con expresiones regulares
    days=0
    hours=0
    minutes=0

    # Buscar "days", "hours" y "minutes" de forma opcional
    if [[ "$uptimeInfo" =~ ([0-9]+)\ days? ]]; then
        days=${BASH_REMATCH[1]}
    fi
    if [[ "$uptimeInfo" =~ ([0-9]+)\ hours? ]]; then
        hours=${BASH_REMATCH[1]}
    fi
    if [[ "$uptimeInfo" =~ ([0-9]+)\ minutes? ]]; then
        minutes=${BASH_REMATCH[1]}
    fi

    # Formatear la salida
    uptimeMessage="Tiempo del servidor activo: $days días, $hours horas y $minutes minutos"

    # Llamada a la función para loguear la información
    mlogtime "$uptimeMessage"
    mloggerflags 6 "$uptimeMessage"
}


# Función para mostrar los usuarios conectados a el servidor
function conectedusers {
    # Cuenta los usuarios únicos conectados
    usercnt=$(who | awk '{print $1}' | sort | uniq | wc -l)

    # Si hay más de un usuario, mostramos "usuarios conectados", de lo contrario "usuario conectado"
    if [[ $usercnt -eq 1 ]]; then
        users="$usercnt usuario conectado a el servidor"
    else
        users="$usercnt usuarios conectados a el servidor"
    fi

    mlogtime "$users"
    mloggerflags 6 "$users"
}

# ------ MONITOREO DEL SISTEMA ------

# Monitoreo en bucles separados
(
    while true; do
    checkbackupscron
    servuptimeuser
    checklogs
    conectedusers
	sleep 86400
    done
) &

(
    while true; do
        openports
        getconnections
        netusage
        sleep 1800
    done
) &

(
    while true; do
        connection
        checkCritSrvcs
        gethighprocess
        swapusage
        DiskUsage
        sleep 900
    done
) &

(
    while true; do
        CPUsage
        RAMUsage
        sleep 10
    done
) &

# Esperar a que los procesos secundarios terminen
wait

# Eliminar el archivo de bloqueo al salir
rm -f $LOCKFILE
