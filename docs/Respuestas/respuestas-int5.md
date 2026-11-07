# Respuestas de control — Integrante 5

## Bloque 1 — Servidor FTP y cuentas

### Punto de control 1

Estado: Sí, realizado.

Se comprobó que el servicio vsftpd estaba activo y funcionando. También se verificaron las cuentas ftp_int1, ftp_int2, ftp_int3, ftp_int4, ftp_int5 y ftp_instructor.

Los usuarios cuentan con su propia carpeta personal y se comprobó el aislamiento entre ellos.

Comandos utilizados:

sudo systemctl status vsftpd

getent passwd ftp_int1 ftp_int2 ftp_int3 ftp_int4 ftp_int5 ftp_instructor

ls -ld /home/ftp_int*

Desde Mint se realizó la prueba FTP contra el servidor:

ftp 192.168.50.1

Se inició sesión con ftp_int2.

Dentro de FTP se comprobó:

pwd

ls

cd /home/ftp_int3

El intento de entrar a la carpeta de otro usuario falló, demostrando el aislamiento.

También se comprobó la subida de archivos:

cd subida

put prueba.txt

### Pregunta de control

¿Por qué FTP simple es inseguro y qué alternativa usaría en producción?

FTP simple es inseguro porque las credenciales y los datos pueden viajar por la red sin cifrado. Una persona que pueda capturar el tráfico podría llegar a obtener el usuario, contraseña o archivos transferidos.

En un ambiente de producción utilizaría SFTP o FTPS, ya que permiten proteger la comunicación mediante cifrado.

---

## Bloque 2 — Scripts de respaldo

### Punto de control 2

Estado: Sí, realizado.

Se generó un respaldo real después de instalar Chamilo.

Archivos principales generados:

chamilo-bd-2026-10-30_0624.sql.gz

chamilo-archivos-2026-10-30_0624.tar.gz

Comando utilizado:

cd ~/proyecto-eif431o

./backups/respaldar.sh

Para revisar los respaldos:

ls -lh ~/respaldos

Para comprobar la integridad de la base:

gzip -t ~/respaldos/chamilo-bd-2026-10-30_0624.sql.gz && echo "BD OK"

Para comprobar la integridad de los archivos:

tar -tzf ~/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz > /dev/null && echo "ARCHIVOS OK"

Para revisar el log:

tail -n 20 ~/respaldos/respaldo.log

La base de datos ocupó aproximadamente 44 KB y el respaldo de los archivos de Chamilo aproximadamente 351 MB.

### Pregunta de control

¿Por qué se respalda también el volumen chamilo_app y no solo la base?

Porque la base de datos no contiene todos los archivos de la plataforma.

El volumen chamilo_app contiene información persistente de Chamilo, como archivos de la plataforma, configuraciones, cursos y archivos subidos.

Si únicamente se respaldara MariaDB, después de una pérdida del volumen podrían recuperarse los registros de la base, pero faltarían los archivos físicos que necesita Chamilo.

Por eso se respaldan ambos elementos: la base de datos y el volumen de archivos.

---

## Bloque 3 — Cron

### Punto de control 3

Estado: Sí, realizado.

Primero se configuró una prueba para ejecutar el respaldo cada minuto.

Para editar Cron:

crontab -e

Línea utilizada durante la prueba:

* * * * * $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1

Durante la prueba se generaron automáticamente varios respaldos.

Se comprobó mediante:

ls -lh ~/respaldos

También se revisó Cron con:

crontab -l

Durante la prueba se detectó que un respaldo tardaba más de un minuto y comenzaron a ejecutarse varios al mismo tiempo.

Para evitar este problema se utilizó flock.

La configuración definitiva quedó:

30 2 * * * /usr/bin/flock -n /tmp/chamilo-respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1

El respaldo se ejecutará diariamente a las 02:30.

La frecuencia diaria se considera suficiente porque la plataforma no tendrá modificaciones constantes.

En el peor caso podrían perderse hasta aproximadamente 24 horas de cambios.

Si existiera un periodo con muchas inscripciones o carga masiva de información sería recomendable aumentar la frecuencia.

### Pregunta de control

¿Por qué Cron necesita exec -T?

Porque una tarea ejecutada por Cron no dispone de una terminal interactiva.

La opción -T evita que Docker intente asignar una terminal al ejecutar el comando dentro del contenedor.

Esto permite que mariadb-dump pueda ejecutarse automáticamente desde Cron sin esperar interacción del usuario.

---

## Bloque 4 — Restauración demostrada

### Punto de control 4

Estado: Sí, restauración realizada.

Antes de eliminar los datos se comprobó que Chamilo funcionaba:

curl -I http://127.0.0.1:8081

Se obtuvo:

HTTP/1.1 200 OK

También se comprobaron 239 tablas en la base de datos.

Comando utilizado:

cd ~/proyecto-eif431o/docker

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'

Para simular la pérdida de los datos:

docker compose down -v

Después se levantó únicamente MariaDB:

docker compose up -d bd

Se restauró la base:

cd ~/proyecto-eif431o

./backups/restaurar.sh ~/respaldos/chamilo-bd-2026-10-30_0624.sql.gz

Después de restaurarla se comprobaron nuevamente las 239 tablas.

Posteriormente se restauraron los archivos:

./backups/restaurar-archivos.sh ~/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz

Finalmente se comprobó:

docker compose ps

curl -I http://127.0.0.1:8081

Chamilo volvió a responder HTTP 200 y los servicios quedaron funcionando correctamente.

### Pregunta de control

¿Qué diferencia hay entre "tengo respaldo" y "puedo restaurar"? ¿Qué se perdió y por qué?

Tener un respaldo solamente significa que existe una copia de los datos.

Poder restaurar significa haber comprobado realmente que esa copia sirve para recuperar el sistema después de una pérdida.

En la prueba se eliminaron los volúmenes de Docker, por lo que se perdieron la base de datos activa y los archivos persistentes de Chamilo.

Los respaldos externos a Docker no se eliminaron.

Después se recuperó la base de datos y los archivos utilizando los scripts de restauración.

Por eso se pudo demostrar que el respaldo no solamente existe, sino que realmente sirve para recuperar la plataforma.

---

## Bloque 5 — Copia fuera del servidor

### Punto de control 5

Estado: Sí, realizado.

Se utilizó una máquina Linux Mint con IP:

192.168.50.101

En Mint se instaló y activó SSH.

Comandos utilizados en Mint:

sudo apt-get install -y openssh-server

sudo systemctl enable --now ssh

sudo systemctl status ssh

Desde el servidor se configuró la conexión SSH y se realizó la copia mediante rsync.

Comando de copia:

rsync -av -e "ssh -i ~/.ssh/respaldo_ed25519" ~/respaldos/ mint@192.168.50.101:~/respaldos-losangeles/

En Mint se verificaron los archivos mediante:

ls -lh ~/respaldos-losangeles/

Se confirmó que estaban presentes, entre otros:

chamilo-bd-2026-10-30_0624.sql.gz

chamilo-archivos-2026-10-30_0624.tar.gz

### Pregunta de control

¿Qué riesgo cubre la copia externa que no cubre el Cron local?

Cron automatiza los respaldos, pero si todos los archivos permanecen dentro de la misma VM, una falla completa de la máquina, del disco o la eliminación de la VM podría destruir tanto el sistema como sus respaldos.

La copia externa mantiene otra copia en un equipo distinto.

Por eso permite recuperar información incluso si el servidor principal deja de existir o pierde completamente su almacenamiento.

---

## Bloque 6 — Documentación final

### Punto de control 6

Estado: En proceso.

Ya se creó y documentó:

docs/respaldos.md

También existen:

README.md

docs/inventario-red.md

docs/decisiones.md

docs/versiones.md

Pendiente para completar totalmente el Bloque 6:

- consolidar el manual de instalación;
- completar o verificar el diagrama de arquitectura;
- reunir las evidencias en docs/evidencias/int5/;
- comprobar el manual con otra persona del equipo siguiendo los pasos desde cero.

La guía establece que el Bloque 6 se considera completo cuando el README está actualizado, existe el diagrama y otra persona del equipo ha probado el manual. 
