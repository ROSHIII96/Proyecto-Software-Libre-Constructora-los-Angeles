# Manual de instalación — Proyecto Constructora Los Ángeles

## Objetivo

Este documento describe los pasos generales para instalar y levantar la plataforma Chamilo LMS del proyecto EIF431O desde un servidor limpio.

La arquitectura utilizada es:

Cliente Linux Mint → DNS BIND9 → Nginx HTTPS del servidor → Balanceador nginx en Docker → Chamilo → MariaDB

---

## 1. Requisitos

Servidor Linux con:

- Git
- Docker Engine
- Docker Compose
- Nginx
- BIND9
- vsftpd
- OpenSSH Server

Versiones principales utilizadas:

- Chamilo 1.11.40
- PHP 8.3
- MariaDB 11.8
- nginx 1.30-alpine

Las versiones completas del proyecto están documentadas en:

docs/versiones.md

---

## 2. Clonar el repositorio

Ejecutar:

git clone https://github.com/ROSHIII96/Proyecto-Software-Libre-Constructora-los-Angeles.git ~/proyecto-eif431o

Entrar al proyecto:

cd ~/proyecto-eif431o

---

## 3. Configurar variables del proyecto

Entrar a Docker:

cd ~/proyecto-eif431o/docker

Copiar el archivo de ejemplo:

cp .env.example .env

Editar:

nano .env

Completar o verificar las variables necesarias:

- Credenciales de MariaDB (`MARIADB_ROOT_PASSWORD`, `DB_NAME`, `DB_USER`, `DB_PASS`)
- Paquete e integridad de Chamilo (`CHAMILO_VERSION`, `PHP_VERSION`, `CHAMILO_URL`, `CHAMILO_SHA256`)
- Variables de auto-aprovisionamiento de Chamilo (`CHAMILO_PORTAL_URL`, `CHAMILO_ADMIN_USER`, `CHAMILO_ADMIN_PASS`, `CHAMILO_ADMIN_EMAIL`, `CHAMILO_DEMO_PASS`)

Las contraseñas reales no deben subirse al repositorio.

Después proteger el archivo:

chmod 600 .env

---

## 4. Configurar DNS

La zona utilizada es:

losangeles.internal

El nombre principal de la plataforma es:

capacitacion.losangeles.internal

El servidor utiliza la dirección:

192.168.50.1

La configuración BIND9 se encuentra en:

dns/

Después de aplicar la configuración verificar:

sudo named-checkconf

sudo named-checkzone losangeles.internal /etc/bind/db.losangeles.internal

Reiniciar BIND9:

sudo systemctl restart bind9

Verificar:

sudo systemctl status bind9

Desde el cliente Mint se puede comprobar con:

nslookup capacitacion.losangeles.internal

---

## 5. Configurar Nginx del servidor

Nginx funciona como punto de entrada HTTPS.

El tráfico sigue esta ruta:

Cliente → Nginx HTTPS → 127.0.0.1:8081 → balanceador Docker → Chamilo

Verificar la configuración:

sudo nginx -t

Reiniciar o recargar:

sudo systemctl reload nginx

Verificar:

sudo systemctl status nginx

---

## 6. Certificado HTTPS

El certificado autofirmado del proyecto se almacena en:

/etc/ssl/losangeles/

Nginx debe utilizar el certificado y su clave correspondiente.

Después de configurarlo:

sudo nginx -t

sudo systemctl reload nginx

---

## 7. Construcción de los contenedores

Entrar a:

cd ~/proyecto-eif431o/docker

Construir y levantar:

docker compose up -d --build

Revisar:

docker compose ps

Los servicios principales son:

bd

chamilo

balanceador

MariaDB y Chamilo deben alcanzar estado healthy.

---

## 8. Instalación y aprovisionamiento automático de Chamilo

En el primer arranque (`docker compose up -d --build`), el entrypoint del contenedor (`docker/chamilo/aprovisionar.sh`) instala y personaliza Chamilo automáticamente sin necesidad de usar el asistente web manual:

1. Ejecuta la instalación desatendida conectando Chamilo con el servicio `bd` (puerto `3306`, base `chamilo`, usuario `chamilo_user`) y la URL `https://capacitacion.losangeles.internal/`.
2. Descomprime e instala el tema corporativo `losangeles` (`docker/personalizacion/losangeles-tema.zip`) y el logo (`logo-los-angeles.png`).
3. Restaura la base de datos inicial (`docker/personalizacion/chamilo-bd.sql.gz`) y los archivos del curso (`curso-SEGOBRA.tar.gz`), que incluyen:
   - Curso **Seguridad en obra** (`SEGOBRA`) con 3 lecciones de contenido real, recurso PDF descargable y evaluación de 5 preguntas.
   - Usuarios creados e inscritos: `admin`, `Instructor1` (Profesor), `estudiante1`, `Estudiante2` y `Estudiante3` (con intentos de evaluación registrados).
4. Actualiza las contraseñas de los usuarios con los valores definidos en `.env` (`CHAMILO_ADMIN_PASS` y `CHAMILO_DEMO_PASS`) mediante `claves.php`.

Para monitorear el progreso del aprovisionamiento hasta ver `aprovisionamiento completo`:

docker compose exec chamilo tail -f /var/www/html/app/aprovisionamiento.log

Después de finalizar se comprueban:

- acceso al panel en `https://capacitacion.losangeles.internal/`;
- funcionamiento del login con `admin`, `Instructor1` y `estudiante1`;
- tema `losangeles` y logo activos;
- conexión con MariaDB;
- eliminación automática del directorio `main/install`;
- configuración persistente en el volumen `chamilo_app`.

---

## 9. Verificación de MariaDB

Entrar al directorio Docker:

cd ~/proyecto-eif431o/docker

Comprobar el servicio:

docker compose ps

Consultar las bases:

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES;"'

Comprobar las tablas de Chamilo:

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'

Durante las pruebas se comprobaron 239 tablas.

---

## 10. Alta disponibilidad de Chamilo

Para levantar dos réplicas:

cd ~/proyecto-eif431o/docker

docker compose up -d --scale chamilo=2

Verificar:

docker compose ps

El balanceador nginx distribuye las solicitudes entre las réplicas.

---

## 11. Configuración FTP

Instalar vsftpd:

sudo apt install vsftpd -y

Respaldar la configuración original:

sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.original

Aplicar la configuración contenida en:

sudo cp ~/proyecto-eif431o/ftp/vsftpd.conf /etc/vsftpd.conf

Reiniciar:

sudo systemctl restart vsftpd

Verificar:

sudo systemctl status vsftpd

Crear los usuarios:

cd ~/proyecto-eif431o

sudo bash ftp/crear-usuarios.sh

Se crean:

ftp_int1

ftp_int2

ftp_int3

ftp_int4

ftp_int5

ftp_instructor

Cada usuario dispone de su propia carpeta y se encuentra aislado de las carpetas de otros usuarios.

---

## 12. Respaldos manuales

El script utilizado es:

backups/respaldar.sh

Dar permisos:

chmod +x backups/respaldar.sh

Ejecutar:

./backups/respaldar.sh

Los respaldos quedan en:

~/respaldos

Se generan:

- respaldo de MariaDB;
- respaldo de archivos de Chamilo.

---

## 13. Verificación de respaldos

Base de datos:

gzip -t ~/respaldos/chamilo-bd-ARCHIVO.sql.gz

Archivos:

tar -tzf ~/respaldos/chamilo-archivos-ARCHIVO.tar.gz > /dev/null

Los procedimientos detallados se encuentran en:

docs/respaldos.md

---

## 14. Automatización con Cron

Editar:

crontab -e

El respaldo se ejecuta diariamente a las 02:30:

30 2 * * * /usr/bin/flock -n /tmp/chamilo-respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1

La copia externa se ejecuta a las 03:00:

0 3 * * * /usr/bin/rsync -av -e "ssh -i $HOME/.ssh/respaldo_cron_ed25519" $HOME/respaldos/ server@192.168.50.101:~/respaldos-losangeles/ >> $HOME/respaldos/rsync.log 2>&1

Verificar:

crontab -l

---

## 15. Configuración de la copia externa

En el equipo destino se debe instalar OpenSSH Server:

sudo apt update

sudo apt install openssh-server -y

sudo systemctl enable --now ssh

Crear la carpeta destino:

mkdir -p ~/respaldos-losangeles

Desde el servidor principal generar y copiar la llave SSH sin frase de paso para el envío automático con `rsync`:

ssh-keygen -t ed25519 -f ~/.ssh/respaldo_cron_ed25519 -N ""
ssh-copy-id -i ~/.ssh/respaldo_cron_ed25519.pub server@192.168.50.101

