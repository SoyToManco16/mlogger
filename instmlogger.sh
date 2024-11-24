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
sourcedest="$mbackups"                  # Ruta del destino de las backups
mlog="/var/log/mlog.log"               
logrotate_conf="/etc/logrotate.d/mlogger"  # Configuración de logrotate para mlogger

# Instalar dependencias
echo "Instalando dependencias"
sudo apt update
sudo apt install util-linux dmidecode iputils-ping gawk procps bc coreutils bsdutils logrotate -y
clear

echo "Preparando todo para usted, espere por favor :)"

# Crear directorios necesarios si no existen
mkdir -p "$etcm" "$mscripts" "$mbackups"  # Crear carpetas necesarias

# Copiar archivos a las rutas correspondientes
cp "$readme" "$etcm" || { echo "Error al copiar README.txt"; exit 1; }
cp "$sclc" "$etcm" || { echo "Error al copiar servcatlog.conf"; exit 1; }
cp mlogger.sh "$ulbp" || { echo "Error al copiar mlogger.sh"; exit 1; }

# Dar permisos de ejecución
chmod +x "$culbp" || { echo "Error al dar permisos a mlogger.sh"; exit 1; }

# Preguntar por las copias de seguridad automáticas
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
    if [[ ! -d "$sourcedir" ]]; then
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

# Configuración de logrotate para el archivo de log de mlogger
echo "Configurando logrotate para mlog"
cat <<EOF | tee "$logrotate_conf" > /dev/null
$mlog {
    daily
    missingok         
    rotate 7          
    compress
    notifempty
    create 0644 root root
}
EOF

# Ejecutar logrotate manualmente para probar la configuración
logrotate --debug "$logrotate_conf"

echo "Instalación completada, disfrute de mlogger :)"
clear
