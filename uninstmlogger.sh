#!/bin/bash

# Variables
sysp="/etc/systemd/system"
ulbp="/usr/local/bin"
vlm="/var/log/mlog.log" 
culbp="$ulbp/mlogger.sh"
bsp="$ulbp/mloggerbackups.sh"  # Script de backup
mbackups="$etcm/backups"
cjp="/etc/cron.d/mloggerbackups-cron"  # Cronjob
etcm="/etc/mlogger"  # Carpeta de configuración
logrotate_conf="/etc/logrotate.d/mlogger"  # Configuración de logrotate

# Eliminar el servicio
echo "Deteniendo y deshabilitando el servicio mlogger..."
systemctl stop mlogger.service
systemctl disable mlogger.service
rm -f "$sysp/mlogger.service"  # Eliminar el archivo del servicio

# Recargar los servicios
systemctl daemon-reload

# Eliminar el cronjob en /etc/cron.d/
if [ -f "$cjp" ]; then
    rm -f "$cjp"
    systemctl restart cron  # Reiniciar el cron para aplicar los cambios
    echo "Cronjob de backup eliminado."
else
    echo "No se encontró el cronjob de backup."
fi

# Eliminar el script de backups
if [ -f "$bsp" ]; then
    rm -f "$bsp"
    echo "Script de backup eliminado."
else
    echo "No se encontró el script de backup."
fi

# Eliminar el script principal
if [ -f "$culbp" ]; then
    rm -f "$culbp"
    echo "Script principal mlogger.sh eliminado."
else
    echo "No se encontró el script principal mlogger.sh."
fi

# Eliminar la configuración de logrotate
if [ -f "$logrotate_conf" ]; then
    rm -f "$logrotate_conf"
    echo "Configuración de logrotate eliminada."
else
    echo "No se encontró la configuración de logrotate."
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
    echo "Renombrando archivo de log a $newmlog..."
    mv "$vlm" "$newmlog"
fi

if [ -d "$etcm" ]; then
    read -p "¿Deseas eliminar la carpeta donde mlogger ha sido instalado (Las backups serán movidas a /home)? (s/n): " confirm_delete
    if [[ "$confirm_delete" == "s" || "$confirm_delete" == "S" ]]; then
        echo "Moviendo carpeta de las backups a /home"

        # Asegurarse de que /home existe
        if [ ! -d "/home" ]; then
            echo "Directorio /home no encontrado, creando..."
            mkdir /home
        fi

        # Comprobar si el directorio de copias de seguridad ya existe en /home
        if [ -d "/home/$(basename "$mbackups")" ]; then
            echo "El directorio de copias de seguridad ya existe en /home, renombrando..."
            mv "$mbackups" "/home/$(basename "$mbackups")_backup_$(date +%F_%T)"
        else
            mv "$mbackups" /home
        fi

        # Comprobar si el movimiento se realizó correctamente
        if [ -d "/home/$(basename "$mbackups")" ]; then
            echo "Carpeta de copias de seguridad movida correctamente a /home."
            echo "Eliminando carpeta mlogger"
            rm -rf "$etcm"  # Eliminar la carpeta y todo su contenido
        else
            echo "Error al mover la carpeta de copias de seguridad. La carpeta mlogger no se ha eliminado."
        fi
    else
        echo "La carpeta '/etc/mlogger' no se ha eliminado."
    fi
else
    echo "No se encontró la carpeta '/etc/mlogger'."
fi


# Finalizar
echo "Desinstalación completada."
