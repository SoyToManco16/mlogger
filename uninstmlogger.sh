#!/bin/bash
# Este script debe ser ejecutado con permisos de root

sysp="/etc/systemd/system"
vlm="/var/log/mlog"
ulbp="/usr/local/bin"
culbp="$ulbp/mlogger.sh"
servf="$sysp/mlogger.service"

# Detener el servicio si está en ejecución
if systemctl is-active --quiet mlogger.service; then
    echo "Deteniendo el servicio mlogger..."
    systemctl stop mlogger.service
fi

# Deshabilitar el servicio para que no se inicie automáticamente
if systemctl is-enabled --quiet mlogger.service; then
    echo "Deshabilitando el servicio mlogger..."
    systemctl disable mlogger.service
fi

# Eliminar el archivo de servicio
if [ -f "$servf" ]; then
    echo "Eliminando archivo de servicio en $servf..."
    rm -f "$servf"
fi

# Eliminar el script de mlogger
if [ -f "$culbp" ]; then
    echo "Eliminando script de mlogger en $culbp..."
    rm -f "$culbp"
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

# Recargar los servicios para aplicar los cambios
echo "Recargando lista de servicios..."
systemctl daemon-reload

# Mensaje de confirmación
echo "Desinstalación de mlogger completada."
clear