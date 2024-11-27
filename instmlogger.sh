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
readme="Documentación"
cjp="/etc/cron.d/mloggerbackups-cron"   # Cronjob copias de seguridad
sourcedest="$mbackups"                  # Ruta del destino de las backups
mlog="/var/log/mlog.log"               
logrotate_conf="/etc/logrotate.d/mlogger"  # Configuración de logrotate para mlogger

# Instalar dependencias
echo "Instalando dependencias"
sudo apt update
sudo apt install util-linux iputils-ping gawk procps bc coreutils bsdutils logrotate at logcheck msmtp -y
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

#!/bin/bash

# Solicitar al usuario habilitar los avisos por email
read -p "¿Desea habilitar los avisos por email ante eventos críticos? (s/n): " ansmail
if [[ "$ansmail" == "s" || "$ansmail" == "S" ]]; then
    read -p "Introduzca la dirección de correo donde se enviarán los avisos (example@gmail.com): " mail
    if [[ -z "$mail" ]]; then
        echo "No se ha introducido ningún mail, desertando..."; exit 1
    fi
    sed -i "s/^#mail=${mail}/" "$culbp"
    read -p "¿Ha configurado ya msmtp en su servidor? (s/n): " msmans

    if [[ "$msmans" == "n" || "$msmans" == "N" ]]; then
        echo "Configurando msmtp..."

        # Verificar si msmtp está instalado
        if ! command -v msmtp &> /dev/null; then
            echo "msmtp no está instalado. Instalándolo ahora..."
            sudo apt update && sudo apt install -y msmtp
        fi

        # Verificar si los certificados CA están instalados
        if [[ ! -f /etc/ssl/certs/ca-certificates.crt ]]; then
            echo "Los certificados CA no están instalados. Instalándolos ahora..."
            sudo apt update && sudo apt install -y ca-certificates
        fi

        # Crear archivo de configuración de msmtp
        sudo touch /etc/msmtprc
        sudo chmod 600 /etc/msmtprc
        sudo chown root:root /etc/msmtprc
        
        cat << EOF | sudo tee /etc/msmtprc > /dev/null
defaults
auth on
tls on
tls_starttls on
tls_certcheck off
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/msmtp.log

account default
host smtp.gmail.com
port 587
from maikel.local17@gmail.com
user maikel.local17@gmail.com
password bfff yncq dsja ihdy
EOF

        # Crear archivo de log para msmtp
        sudo touch /var/log/msmtp.log
        sudo chmod 600 /var/log/msmtp.log
        sudo chown root:root /var/log/msmtp.log

        # Prueba de envío de correo
        echo -e "To: $mail\nSubject: Prueba de configuración de msmtp\n\nEste es un mensaje de prueba." | msmtp -t
        if [[ $? -eq 0 ]]; then
            echo "Correo de prueba enviado correctamente a $mail."
        else
            echo "Error al enviar el correo de prueba. Revisa la configuración."
        fi
    else
        echo "msmtp ya está configurado. Continuando..."
    fi
else 
    echo "Continuando con la instalación :)"
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
logrotate "$logrotate_conf"

echo "Instalación completada, disfrute de mlogger :)"

