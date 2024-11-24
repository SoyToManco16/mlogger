#!/bin/bash

# Rutas de los archivos y directorios
sysp="/etc/systemd/system"
ulbp="/usr/local/bin"
culbp="$ulbp/mlogger.sh"
servf="$sysp/mlogger.service"
mbs="mloggerbackups.sh"
etcm="/etc/mlogger"
mscripts="$etcm/scripts"
mbackups="$etcm/backups"
sclc="servcatlog.conf"
readme="README.txt"
cjp="/etc/cron.d/mloggerbackups-cron"   # Cronjob copias de seguridad
sourcedest="$mbackups"              # Ruta del destino de las backups

# Instalar dependencias
echo "Instalando dependencias"
sudo apt update
sudo apt install util-linux dmidecode iputils-ping gawk procps bc coreutils bsdutils
clear

echo "Preparando todo para usted, espere por favor :)"

mkdir -p $etcm                  # Crear carpeta en etc
mkdir -p $mscripts              # Crear carpeta de scripts en /etc/mlogger
mkdir -p $
cp "$readme" "$etcm"            # Copiar archivo README a /etc/mlogger
cp "$sclc" "$etcm"              # Copiar archivo de configuración de servicios a /etc/mlogger
cp mlogger.sh "$ulbp"           # Copiar script principal a /usr/local/bin
chmod +x "$culbp"               # Dar permisos de ejecución a el script principal

# Preguntar por si queremos habilitar el modo de copias de seguridad de mlogger
read -p "¿Quieres habilitar las copias de seguridad automáticas? (s/n): " enablebackups
if [[ "$enablebackups" == "s" || "$enablebackups" == "S" ]]; then
    # Verificar si el script de backup está presente
    if [ ! -f "$mbs" ]; then
        echo "El script de copias de seguridad no está presente. Asegúrese de tenerlo en la misma carpeta que este script."
        exit 1
    fi

    # Solicitar directorios de backup
    echo "Las copias de seguridad se guardan en $mbackups"
    read -p "Introduce el directorio de origen para las copias de seguridad: " sourcedir

    # Validación de directorios
    if [[ ! -d "$sourcedir" || ! -d "$sourcedest" ]]; then
        echo "El directorio no existe. Saliendo..."
        exit 1
    fi

    # Copiar y ajustar script de backup
    cp "$mbs" "$mscripts" && chmod +x "$mscripts/mloggerbackups.sh"
    sed -i "s|#ORIGEN_DIR#|$sourcedir|g" "$mscripts/mloggerbackups.sh"
    sed -i "s|#DESTINO_DIR#|$sourcedest|g" "$mscripts/mloggerbackups.sh"
    
    # Crear cronjob si no existe
    if ! grep -q "$mscripts/mloggerbackups.sh" "$cjp"; then
        echo "0 3 * * * root $mscripts/mloggerbackups.sh" > "$cjp"
        systemctl restart cron
    else
        echo "El cronjob ya está configurado."
    fi
else
    echo "Continuando con la Instalación"
fi

# Crear el archivo de servicio si no existe
if [ ! -f "$servf" ]; then
    echo "Generando archivo de configuración de servicio de mlogger"
    cat <<EOF | tee "$servf" > /dev/null
[Unit]
Description=Mlogger
After=network.target

[Service]
ExecStart=$ulbp/mlogger.sh
Type=simple
Restart=always
PIDFile=/run/monitoring.pid

[Install]
WantedBy=multi-user.target
EOF
fi

# Reiniciar el sistema de servicios
systemctl daemon-reload

# Habilitar e iniciar el servicio
if ! systemctl is-enabled mlogger.service > /dev/null; then
    systemctl enable mlogger.service
else
    echo "El servicio ya está habilitado."
fi

systemctl start mlogger.service
echo "Instalación completada, disfrute de mlogger :)"
clear
