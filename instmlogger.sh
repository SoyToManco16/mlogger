#!/bin/bash

# Este script debe ser ejecutado en esta carpeta y como root

sysp="/etc/systemd/system"
ulbp="/usr/local/bin"
culbp="$ulbp/mlogger.sh"
servf="$sysp/mlogger.service"
mbs="mloggerbackups.sh"  # Nombre del script de backup
bsp="$ulbp/$mbs"  # Ruta final del script de backup
cjp="/etc/cron.d/mloggerbackups-cron"  # Fichero cron donde añadiremos el job

# Instalar dependencias
echo "Instalando dependencias"
sudo apt update
sudo apt install util-linux dmidecode iputils-ping gawk procps bc coreutils bsdutils
clear

# Comprobamos si existe el script principal mlogger.sh en el fichero o no
if [ ! -f "$culbp" ]; then 
    echo "Moviendo el script a $ulbp"
    cp mlogger.sh "$ulbp"
    chmod +x "$culbp"
fi

# Comprobamos si el script de backup mloggerbackups.sh existe en la carpeta actual
if [ ! -f "$mbs" ]; then
    echo "El script de copias de seguridad no está presente. Asegúrese de tenerlo en la misma carpeta que este script."
    exit 1
fi

# Preguntamos al usuario si quiere habilitar las copias de seguridad
read -p "¿Quieres habilitar las copias de seguridad automáticas? (s/n): " enablebackups
if [[ "$enablebackups" == "s" || "$enablebackups" == "S" ]]; then
    # Solicitamos los directorios para las copias de seguridad
    read -p "Introduce el directorio donde se realizarán las copias de seguridad (por ejemplo, /home/user/backups): " sourcedir
    read -p "Introduce el directorio donde se guardarán las copias de seguridad (por ejemplo, /mnt/backups): " sourcedest

    # Movemos el script de backup a /usr/local/bin
    echo "Moviendo el script de copias de seguridad a $ulbp"
    cp "$mbs" "$ulbp"
    chmod +x "$bsp"

    # Usamos sed para insertar los directorios en el script de backups
    echo "Insertando los directorios en el script de backup"
    sed -i "s|#ORIGEN_DIR#|$sourcedir|g" "$bsp"
    sed -i "s|#DESTINO_DIR#|$sourcedest|g" "$bsp"

    # Creamos el cronjob que se ejecutará todos los días a las 3 AM
    echo "Creando cronjob para ejecutar el script de backup todos los días a las 3 AM"
    echo "0 3 * * * root $bsp" > "$cjp"

    # Añadir el cronjob
    echo "0 3 * * * root /usr/local/bin/mloggerbackups.sh" | sudo tee -a /etc/crontab

    # Reiniciamos el cron
    systemctl restart cron

    echo "Copias de seguridad habilitadas, continuando con la instalación"
else
    echo "Continuando con la Instalación"
fi

# Si el servicio no está creado lo crea
if [ ! -f "$servf" ]; then
    echo "Generando archivo de configuración de servicio de mlogger"
    cat <<EOF > "$servf"
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

# Reiniciamos la lista de servicios 
systemctl daemon-reload

# Habilitamos el servicio 
systemctl enable mlogger.service

# Y lo iniciamos 
systemctl start mlogger.service
echo "Instalación completada, disfrute de mlogger :)"
clear
