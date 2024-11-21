#!/bin/bash

# Recibir los directorios
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "ERROR: Debes proporcionar los directorios de origen y destino."
  echo "Uso: $0 <directorio_origen> <directorio_destino>"
  exit 1
fi

# Directorios de origen y destino recibidos como parámetros
sourcedir="$1"
destdir="$2"
backupname="backup-$(date +'%y-%m-%d').tar.gz"  # Nombre del archivo de backup con formato YY-MM-DD

# Verificamos si los directorios existen
if [ ! -d "$sourcedir" ]; then
  echo "ERROR: El directorio de origen $sourcedir no existe."
  exit 1
fi

if [ ! -d "$destdir" ]; then
  echo "ERROR: El directorio de destino $destdir no existe."
  exit 1
fi

# Creamos el archivo de backup con tar y lo guardamos en el directorio destino
echo "Realizando copia de seguridad de $sourcedir a $destdir/$backupname"

# Comando tar para crear un archivo comprimido .tar.gz
tar -czf "$destdir/$backupname" -C "$sourcedir" .

# Verificamos si la operación fue exitosa
if [ $? -eq 0 ]; then
  echo "Copia de seguridad realizada exitosamente: $destdir/$backupname"
else
  echo "ERROR: Hubo un problema al realizar la copia de seguridad."
  exit 1
fi
