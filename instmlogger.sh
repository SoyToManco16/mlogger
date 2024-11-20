#!/bin/bash

# Instalar dependencias
echo "Instalando dependencias"
sudo apt update
sudo apt install util-linux dmidecode iputils-ping gawk procps bc coreutils bsdutils
clear

# Este script debe ser ejecutado en esta carpeta y como root

sysp="/etc/systemd/system"
ulbp="/usr/local/bin"
culbp="$ulbp/mlogger.sh"
servf="$sysp/mlogger.service"

# Comprobamos si existe el script en el fichero o no
if [ ! -f "$culbp" ]; then 
    echo "Moviendo el script a $ulbp"
    cp mlogger.sh "$ulbp"
    chmod +x "$culbp"
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
