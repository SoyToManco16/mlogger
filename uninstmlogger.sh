#!/bin/bash

# Variables
sysp="/etc/systemd/system"
ulbp="/usr/local/bin"
vlm="/var/log/mlog"
culbp="$ulbp/mlogger.sh"
bsp="$ulbp/mloggerbackups.sh"  # Script de backup
cjp="/etc/cron.d/mloggerbackups-cron"  # Cronjob
etcm="/etc/mlogger"  # Carpeta de configuración

# Eliminar el servicio
echo "Deteniendo y deshabilitando el servicio mlogger..."
systemctl stop mlogger.service
systemctl disable mlogger.service
rm -f "$sysp/mlogger.service"  # Eliminar el archivo del servicio

# Recargar los servicios
systemctl daemon-reload

# Eliminar el cronjob si existe
if [ -f "$cjp" ]; then
    rm -f "$cjp"
    systemctl restart cron  # Reiniciar el cron para aplicar los cambios
fi

# Eliminar el script de backups
if [ -f "$bsp" ]; then
    rm -f "$bsp"
fi

# Renombrar mlog como antiguo si existe
if [[ -f "$vlm" ]]; then
    count=0
    newmlog="${vlm}.old"

    # Bucle para encontrar un nombre de archivo único
    while [[ -f "${newmlog}" ]]; do
        newmlog="${vlm}.old.${count}"
        count=$((count + 1))
    done

    # Renombrar el archivo con el nuevo nombre único
    mv "$vlm" "$newmlog"
fi

# Eliminar el script principal
if [ -f "$culbp" ]; then
    rm -f "$culbp"
fi

# Eliminar la carpeta de configuración y todos sus archivos (si existe)
if [ -d "$etcm" ]; then
    read -p "¿Estás seguro de que deseas eliminar la carpeta de configuración '/etc/mlogger' y todo su contenido? (s/n): " confirm_delete
    if [[ "$confirm_delete" == "s" || "$confirm_delete" == "S" ]]; then
        rm -rf "$etcm"  # Eliminar la carpeta y todo su contenido
    else
        echo "La carpeta '/etc/mlogger' no se ha eliminado."
    fi
else
    echo "No se encontró la carpeta '/etc/mlogger'."
fi

# Finalizar
echo "Desinstalación completada."
clear
