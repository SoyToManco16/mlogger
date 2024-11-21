#!/bin/bash

# Variables globales
mlog="/var/log/mlog"
LOCKFILE="/tmp/mlogger.lock"

# Imprimir delimitadores
function mlogdelimit {
    local del=$1
    local num=$2
    printf '%*s\n' $num | tr ' ' "$del"
    # Uso: mlgdelimit '*_-#' 50
}

# Diccionario de servicios con sus niveles de criticidad
declare -A servcatlog=(
    # Nivel 0: Críticos
    ["networking"]="0",
    ["sshd"]="0",
    ["cron"]="0",
    ["rsyslog"]="0",
    ["systemd-journald"]="0",
    ["firewalld"]="0",
    ["ufw"]="0",
    ["ntp"]="0",
    ["chrony"]="0",

    # Nivel 1: Importantes
    ["mysql"]="1",
    ["mariadb"]="1",
    ["postgresql"]="1",
    ["redis"]="1",
    ["apache2"]="1",
    ["nginx"]="1",
    ["php7.4-fpm"]="1",
    ["lvm2-monitor"]="1",
    ["blk-availability"]="1",
    ["apparmor"]="1",
    ["selinux"]="1",
    ["fail2ban"]="1",
    ["nfs-server"]="1",
    ["rpcbind"]="1",
    ["zabbix-server"]="1",
    ["zabbix-agent"]="1",

    # Nivel 2: Menos críticos
    ["docker"]="2",
    ["containerd"]="2",
    ["lvm2-monitor"]="2",
    ["libvirtd"]="2",
    ["kubelet"]="2",
    ["snapd"]="2",
    ["cups"]="2",
    ["openvnp"]="2",
    ["tomcat"]="2",
    ["wildfly"]="2",

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

# Función para agregar la hora al log
mlogtime() {
    mlogdelimit '_' 100 >> "$mlog"
    echo >> "$mlog"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$mlog"
}

function getsysteminfo {
# Obtener información del SO
SO=$(hostnamectl | awk ' /Operating System/ {print $3, $4, $5}')
KERNELV=$(hostnamectl | awk '/Kernel/ {print $3, $4}')
SNAME=$(hostname)
HWM=$(hostnamectl | awk ' /Hardware Model/ {print $3, $4, $5}')

# Información de la CPU
ARCH=$(lscpu | grep "Architecture" | awk '{print $2}')
CPUM=$(lscpu | grep "^Model name" | awk -F: '{print $2}' | sed 's/^ *//')
CRPU=$(lscpu | grep "^Core(s) per socket" | awk '{print $4}')
TCPU=$(lscpu | grep "^Thread(s) per core" | awk '{print $4}')
ECPU=$(lscpu | grep "^CPU(s):" | awk '{print $2}')

# Información de la memoria RAM
TMEM=$(lsmem | awk ' /Total online memory:/ {print $4}')
NUMEM=$(lsmem | awk ' /Total offline memory:/ {print $4}')

# Información de los dispositivos de almacenamiento
info_discos=""
disks=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}')
index=1

for disk in $disks; do
    # Obtener el modelo del disco
    model=$(sudo udevadm info --query=all --name=/dev/$disk | grep 'ID_MODEL=' | cut -d'=' -f2)

    # Obtener el tamaño del disco
    size=$(lsblk -dno SIZE /dev/$disk)

    # Inicializar variables para espacio usado y libre
    total_used=0
    total_free=0

    # Obtener todas las particiones del disco y sumar el espacio usado y libre
    partitions=$(lsblk -ln -o NAME,MOUNTPOINT | grep "^$disk" | awk '$2!="" {print $1}')
    for part in $partitions; do
        part_used=$(df -B1 --output=used "/dev/$part" 2>/dev/null | tail -n 1)
        part_avail=$(df -B1 --output=avail "/dev/$part" 2>/dev/null | tail -n 1)

        if [ -n "$part_used" ] && [ -n "$part_avail" ]; then
            total_used=$((total_used + part_used))
            total_free=$((total_free + part_avail))
        fi
    done

    # Convertir los valores de espacio a formato legible
    used=$(numfmt --to=iec --suffix=B $total_used)
    free=$(numfmt --to=iec --suffix=B $total_free)

    # Añadir la información a la variable con un espacio extra entre discos
    info_discos+="Disco $index:\n"
    info_discos+="Modelo: $model\n"
    info_discos+="Tamaño: $size\n"
    info_discos+="Espacio usado: $used\n"
    info_discos+="Espacio libre: $free\n\n\n"
    index=$((index + 1))
done

# Redirigir toda la salida al archivo mlogger_output.txt
{
    echo "BIENVENIDO A MLOGGER"
    sleep 1
    echo
    echo "INFORMACIÓN DEL SISTEMA"
    mlogdelimit '=' 70
    echo "Información general"
    echo "Nombre del sistema: $SNAME"
    echo "SO Instalado: $SO"
    echo "Version del kernel: $KERNELV"
    echo "Modelo de hardware: $HWM"
    mlogdelimit '=' 70
    echo "Información de la CPU"
    echo "Modelo de la CPU: $CPUM"
    echo "Arquitectura del procesador: $ARCH"
    echo "Núcleos de la CPU: $CRPU"
    echo "Núcleos habilitados: $ECPU"
    echo "Hilos de la CPU: $TCPU"
    mlogdelimit '=' 70
    echo "Información de la memoria RAM"
    echo "Memoria total instalada: $TMEM"
    echo "Memoria total no usada: $NUMEM"
    mlogdelimit '=' 70
    echo "Información de los dispositivos de almacenamiento instalados"
    echo "Dispositivos conectados"
    echo -e "$info_discos" # Muestra los discos duros instalados
} > "$mlog"

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
    # Leer la primera línea de /proc/stat
    cpu_line=$(head -n 1 /proc/stat)

    # Obtener los valores de tiempo de CPU
    cpu_idle=$(echo $cpu_line | awk '{print $5}')
    cpu_total=$(echo $cpu_line | awk '{print $2+$3+$4+$5+$6+$7+$8}')

    # Esperar un segundo
    sleep 1

    # Leer la primera línea de /proc/stat de nuevo
    cpu_line_new=$(head -n 1 /proc/stat)

    # Obtener los nuevos valores de tiempo de CPU
    cpu_idle_new=$(echo $cpu_line_new | awk '{print $5}')
    cpu_total_new=$(echo $cpu_line_new | awk '{print $2+$3+$4+$5+$6+$7+$8}')

    # Calcular el uso de la CPU
    cpu_idle_diff=$((cpu_idle_new - cpu_idle))
    cpu_total_diff=$((cpu_total_new - cpu_total))
    cpu_usage=$((100 * (cpu_total_diff - cpu_idle_diff) / cpu_total_diff))

    if [[ $cpu_usage -gt 90 ]]; then
        mloggerflags 2 "CRITICAL: El uso de la CPU ha sobrepasado el 90%, por favor revise el servidor"
    elif [[ $cpu_usage -gt 80 ]]; then
        mlogtime "WARNING: El uso de la CPU ha sobrepasado el 80%"
    fi
}


# Función para monitorear el uso de la RAM
function RAMUsage {
    # Leer los valores de memoria desde /proc/meminfo
    total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    free_memory=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

    # Convertir los valores de memoria de kB a MB para mayor precisión
    total_memory_mb=$((total_memory / 1024))
    free_memory_mb=$((free_memory / 1024))

    # Calcular el porcentaje de uso de RAM
    used_memory=$((total_memory_mb - free_memory_mb))
    ram_usage=$((100 * used_memory / total_memory_mb))

    if [[ $ram_usage -gt 90 ]]; then
        mloggerflags 2 "CRITICAL: El uso de la memoria ha superado el 90%!!"
    elif [[ $ram_usage -gt 80 ]]; then 
        mlogtime "WARNING: El uso de la memoria ha superado el 80%"
    fi
}


# Función para monitorear el uso del disco
function DiskUsage {
    df -h | grep -E '^/dev/' | awk '{print $1 " " $5}' | while read line; do
        partition=$(echo $line | awk '{print $1}')
        usage=$(echo $line | awk '{print $2}' | sed 's/%//')
        if [[ ! -z "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
            if [[ $usage -gt 95 ]]; then
                mloggerflags 0 "PANIC: El uso del disco en $partition ha sobrepasado el 95%, por favor revise el servidor"
            elif [[ $usage -gt 90 ]]; then
                mloggerflags 1 "ALERT: El uso del disco en $partition ha sobrepasado el 90%, por favor revise el servidor"
            elif [[ $usage -gt 80 ]]; then
                mlogtime "WARNING: El uso del disco en $partition ha sobrepasado el 80%"
            fi
        else
            echo "Error: Valor de uso de disco no válido para la partición $partition"
        fi
    done
}


# Función para verificar y categorizar servicios críticos
function checkCritSrvcs {
    for service in "${!servcatlog[@]}"; do
        local level="${servcatlog[$service]}"

        # Verificar si el servicio está instalado
        if ! systemctl show "$service" --no-pager > /dev/null 2>&1; then
            continue
        fi

        # Verificar si el servicio está activo
        if ! systemctl is-active --quiet "$service"; then
            case "$level" in
                0)
                    mloggerflags 0 "CRITICAL: El servicio $service está detenido o fallando"
                    ;;
                1)
                    mloggerflags 1 "ALERT: El servicio $service no está activo"
                    ;;
                2)
                    mlogtime "WARNING: El servicio $service no está activo"
                    ;;
            esac

            # Intentar activar/reiniciar el servicio si es de categoría 0 o 1
            if [[ "$level" -eq 0 || "$level" -eq 1 ]]; then
                if systemctl restart "$service" > /dev/null 2>&1; then
                    mlogtime "SUCCESS: Se reinició el servicio $service exitosamente."
                else
                    mloggerflags 0 "ERROR: No se pudo reiniciar el servicio $service. Verifique manualmente."
                fi
            fi
        else
            mlogtime "$service está activo."
        fi
    done
}

# Función para monitorear errores en los logs
function checklogs {
    for log in "${!logfiles[@]}"; do
        echo "Buscando errores en ${log##*/}..."
        if [[ -f "$log" ]]; then
            # Buscar errores en el archivo de log
            errors=$(grep -i "${logfiles[$log]}" "$log")
            if [[ -n "$errors" ]]; then
                mlogtime "Errores en ${log##*/}"
                # Mandar los errores a mlog con delimitador y descripción
                echo "$errors" >> "$mlog"

                # También mandamos los errores al logger con el nivel de error
                mloggerflags 3 "Errores encontrados en ${log##*/}: $errors"
            fi
        else
            continue # Si no encuentra el log, continúa
        fi
    done
}

# ------ PRIORIDAD MEDIA ------
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

function netusage {
    checknet=$(ifstat -t 1 5)
    mlogtime "Estadísticas del uso de red (5 segundos atrás)"
    echo "$checknet" >> "$mlog"
}

function openports {
    sopenports=$(nmap -sS -sU -p- localhost | sed -n '/PORT/,/Nmap scan report/{/Nmap scan report/!p}')
    mlogtime "Escaneo de puertos y servicios usados"
    echo "$sopenports" >> "$mlog"
}

#function checkcron {
#    echo "$cronjobs" >> "$mlog"
#}

#function backups {
#    echo "$backup" >> "$mlog"
#}

function updatesystem {
    apt update && apt upgrade -y
    if [[ $? -ne 0 ]]; then
    mlogtime "No se ha podido actualizar el sistema, por favor revise si hay bloqueos en dpkg"
    fi
}

# ------ PRIORIDAD BAJA ------
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

# ------ INFORMACIÓN DEL SISTEMA ------

getsysteminfo

# ------ MONITOREO DEL SISTEMA ------

# Monitoreo en bucles separados
(
    while true; do
	updatesystem
	sleep 86400
    done
) &

(
    while true; do
        checklogs
        sleep 43200
    done
) &

(
    while true; do
        servuptimeuser
        sleep 3600
    done
) &

(
    while true; do
        openports
        sleep 1800
    done
) &

(
    while true; do
        connection
        conectedusers
        checkCritSrvcs
        gethighprocess
        swapusage
        sleep 900
    done
) &

(
    while true; do
        DiskUsage
        sleep 300
    done
) &

(
    while true; do
        netusage
        sleep 180
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
