Mlogger es un servicio creado para la monitorización de su sistema linux / ubuntu en entorno servidor preferiblemente.
Cuenta con diversas funcionalidades como la creación de registros generales tanto como registros a nivel de red.
Debemos instalar mlogger como root o usuario administrador.
Ejecutaremos "instmlogger" y nos solicitará algo de información.

En la carpeta del programa vienen dos ficheros uno de configuración y otro con unos cuantos servicios comunes en servidores.
Este archivo se llama servcatlog.conf y cuando instalemos nuestro sistema estará presente en /etc/mlogger.
Podemos editarlo siguiendo la siguiente configuración:
Servicios muy críticos: service=0
Servicios menos críticos pero no menos importantes: service=1
Servicios no muy críticos: service=2

Si habilitamos el script de copias de seguridad, este nos permite crear copias de seguridad de un directorio que especifiquemos
y las guardará en programa tar.gz.

Si queremos habilitar los avisos por correo electrónico se nos pedirá un correo a la hora de la instalación.
Por ahora solo soportamos correos basados en gmail :(.

Para más detalles lea la documentación del proyecto.
Con cariño de SoyToManco16 :)

