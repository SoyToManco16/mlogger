#!/bin/bash

# Variables
sysp="/etc/systemd/system"
ulbp="/usr/local/bin"
culbp="$ulbp/mlogger.sh"
bsp="$ulbp/mloggerbackups.sh"  # Script de backup
cjp="/etc/cron.d/mloggerbackups-cron"  # Cronjob

# Eliminar el servicio
echo "Deteniendo y deshabilitando el servicio mlogger..."
systemctl stop mlogger.service
systemctl disable mlogger.service
rm -f "$sysp/mlogger.service"  # Eliminar el archivo del servicio

# Recargar los servicios
systemctl daemon-reload

# Eliminar el cronjob si existe
if [ -f "$cjp" ]; then
    echo "Eliminando el cronjob de copias de seguridad..."
    rm -f "$cjp"
    systemctl restart cron  # Reiniciar el cron para aplicar los cambios
else
    echo "No se encontró el cronjob de copias de seguridad."
fi

# Eliminar el script de backups
if [ -f "$bsp" ]; then
    echo "Eliminando el script de copias de seguridad..."
    rm -f "$bsp"
fi

# Eliminar el script principal
if [ -f "$culbp" ]; then
    echo "Eliminando el script principal mlogger.sh..."
    rm -f "$culbp"
fi

# Finalizar
echo "Desinstalación completada."
clear
