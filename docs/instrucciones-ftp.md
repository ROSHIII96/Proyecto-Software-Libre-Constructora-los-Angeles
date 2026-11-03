# Instalación y configuración del servicio FTP

## 1. Instalar vsftpd

Actualizar los paquetes:

sudo apt update

Instalar vsftpd:

sudo apt install vsftpd -y

## 2. Respaldar la configuración original

Crear una copia del archivo de configuración:

sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.original

## 3. Configurar vsftpd

Editar el archivo:

sudo cp ~/proyecto-eif431o/ftp/vsftpd.conf /etc/vsftpd.conf

Asegurarse de tener las siguientes opciones:

anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_umask=077

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100

Estas opciones permiten:

- Desactivar usuarios anónimos.
- Permitir usuarios locales.
- Permitir escritura y subida de archivos.
- Aislar cada usuario en su directorio.
- Utilizar el modo pasivo.
- Utilizar los puertos 40000 al 40100 para FTP pasivo.

Guardar el archivo con:

Ctrl + O

Enter

Ctrl + X

## 4. Reiniciar el servicio

Reiniciar vsftpd:

sudo systemctl restart vsftpd

Habilitarlo para que inicie automáticamente:

sudo systemctl enable vsftpd

Comprobar el estado:

sudo systemctl status vsftpd

Debe aparecer:

active (running)

## 5. Verificar la configuración

Ejecutar:

grep -E "anonymous_enable|local_enable|write_enable|chroot_local_user|allow_writeable_chroot|local_umask|pasv_enable|pasv_min_port|pasv_max_port" /etc/vsftpd.conf

Debe mostrar las opciones configuradas anteriormente.

## 6. Crear los usuarios FTP

El proyecto incluye el script:

ftp/crear-usuarios.sh

Ejecutarlo desde la raíz del proyecto:

cd ~/proyecto-eif431o

sudo bash ftp/crear-usuarios.sh

Los usuarios utilizados son:

ftp_int1
ftp_int2
ftp_int3
ftp_int4
ftp_int5
ftp_instructor

## 7. Verificar los usuarios

Ejecutar:

getent passwd ftp_int1 ftp_int2 ftp_int3 ftp_int4 ftp_int5 ftp_instructor

También se pueden revisar los directorios:

ls -ld /home/ftp_int\*

Cada usuario debe tener su propio directorio.

## 8. Probar FTP desde Linux Mint

Desde la máquina Linux Mint:

ftp 192.168.50.1

Ingresar con un usuario, por ejemplo:

ftp_int2

Después introducir la contraseña correspondiente.

Dentro de FTP se pueden utilizar:

pwd

ls

cd subida

put prueba-ftp.txt

ls

Para descargar:

get prueba-ftp.txt prueba-descargada.txt

Para salir:

bye

## 9. Prueba de subida

Antes de entrar al FTP se puede crear un archivo en Mint:

echo "Prueba FTP Constructora Los Angeles" > prueba-ftp.txt

Después:

ftp 192.168.50.1

Dentro:

cd subida

put prueba-ftp.txt

ls

El archivo prueba-ftp.txt debe aparecer en la carpeta.

## 10. Prueba de aislamiento

Conectado como:

ftp_int2

Intentar ingresar al directorio de otro usuario:

cd /home/ftp_int3

El servidor debe rechazar el acceso mostrando un mensaje similar a:

550 Failed to change directory

Esto demuestra que los usuarios se encuentran aislados.

## 11. Puertos utilizados

FTP:

Puerto 21

FTP pasivo:

40000-40100

## 12. Resultado

Se comprobó:

- instalación de vsftpd;
- servicio activo;
- usuarios FTP locales;
- usuarios aislados;
- subida de archivos;
- descarga de archivos;
- modo pasivo configurado;
- acceso desde Linux Mint.

El servicio FTP quedó funcionando correctamente para las pruebas del proyecto.
