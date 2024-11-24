#!/bin/bash

# Imprimir delimitadores
function mlogdelimit {
    local del=$1
    local num=$2
    printf '%*s\n' $num | tr ' ' "$del"
    # Uso: mlgdelimit '*_-#' 50
}

# Meter datos en mlog
mlogtime() {
    mlogdelimit '_' 100 >> "$mlog"
    echo >> "$mlog"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$mlog"
}

# Definir directorios (estos valores serán reemplazados por el script de instalación)
origen="#ORIGEN_DIR#"
destino="#DESTINO_DIR#"

# Verificamos que el directorio de origen exista
if [ ! -d "$origen" ]; then
    echo "El directorio de origen no existe: $origen"
    exit 1
fi

# Verificamos que el directorio de destino exista
if [ ! -d "$destino" ]; then
    echo "El directorio de destino no existe: $destino"
    exit 1
fi

# Creamos el nombre del archivo de backup
fecha=$(date "+%Y-%m-%d")
backupfile="backup-$fecha.tar.gz"

# Realizamos la copia de seguridad utilizando tar
mlogtime "Realizando copia de seguridad de $origen a $destino/$backupfile..."
tar -czf "$destino/$backupfile" -C "$origen" .

# Verificamos si el proceso de copia de seguridad fue exitoso
if [ $? -eq 0 ]; then
    echo "Copia de seguridad completada exitosamente."
else
    echo "Error al realizar la copia de seguridad."
fi
