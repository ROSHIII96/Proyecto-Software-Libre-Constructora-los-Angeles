# Política y pruebas de respaldos — Constructora Los Ángeles

## Responsable

Integrante 5, con apoyo del Integrante 4 para la base de datos MariaDB.

---

## 1. Ubicación de los respaldos

Los respaldos se almacenan fuera de Docker y fuera del repositorio Git:

~/respaldos

Para comprobar el contenido de la carpeta:

ls -lh ~/respaldos

Para comprobar cuánto espacio disponible existe en el servidor:

df -h

De esta forma, eliminar o recrear los contenedores no elimina automáticamente los respaldos.

---

## 2. Elementos respaldados

El proyecto genera dos tipos de respaldo:

1. Base de datos MariaDB de Chamilo.
2. Archivos persistentes almacenados en el volumen chamilo_app.

La base de datos se respalda mediante mariadb-dump ejecutado dentro del contenedor bd.

Los archivos de Chamilo se comprimen desde el volumen Docker mediante tar.

Para comprobar los servicios Docker disponibles:

cd ~/proyecto-eif431o/docker

docker compose config --services

Los servicios esperados son:

bd

chamilo

balanceador

Para revisar el estado de los contenedores:

docker compose ps

---

## 3. Script utilizado

El script principal de respaldos es:

backups/respaldar.sh

Para darle permisos de ejecución:

cd ~/proyecto-eif431o

chmod +x backups/respaldar.sh

Para comprobar los permisos:

ls -l backups/respaldar.sh

El script:

- crea respaldos con fecha y hora;
- utiliza archivos temporales .tmp;
- renombra el archivo únicamente cuando el respaldo termina correctamente;
- registra los resultados en ~/respaldos/respaldo.log;
- elimina respaldos con más de 7 días de antigüedad;
- toma las credenciales desde las variables del contenedor y no guarda contraseñas en el script.

Para comprobar la sintaxis:

bash -n backups/respaldar.sh && echo "Sintaxis del script OK"

---

## 4. Prueba manual del respaldo

Para ejecutar manualmente el respaldo:

cd ~/proyecto-eif431o

./backups/respaldar.sh

Después de instalar Chamilo se generaron:

chamilo-bd-2026-10-30_0624.sql.gz

chamilo-archivos-2026-10-30_0624.tar.gz

Para revisar los archivos:

ls -lh ~/respaldos

El respaldo de la base ocupó aproximadamente 44 KB y el respaldo de archivos aproximadamente 351 MB.

Para revisar el log:

tail -n 20 ~/respaldos/respaldo.log

Se obtuvieron resultados similares a:

OK BD: /home/server/respaldos/chamilo-bd-2026-10-30_0624.sql.gz

OK ARCHIVOS: /home/server/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz

---

## 5. Verificación de integridad

Para comprobar la base:

gzip -t ~/respaldos/chamilo-bd-2026-10-30_0624.sql.gz && echo "BD OK"

Resultado:

BD OK

Para comprobar los archivos:

tar -tzf ~/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz > /dev/null && echo "ARCHIVOS OK"

Resultado:

ARCHIVOS OK

También se revisó el contenido del respaldo SQL:

zcat ~/respaldos/chamilo-bd-2026-10-30_0624.sql.gz | head -n 30

Esto permitió comprobar que corresponde a un dump real de MariaDB de la base chamilo.

---

## 6. Verificación de la base de datos

Para comprobar el acceso a MariaDB:

cd ~/proyecto-eif431o/docker

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT 1;"'

Para contar las tablas:

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'

Después de instalar Chamilo se comprobaron:

239 tablas

---

## 7. Automatización con Cron

Primero se realizó una prueba temporal ejecutando el respaldo cada minuto.

Para editar Cron:

crontab -e

Línea utilizada durante la prueba:

* * * * * $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1

Para revisar las tareas:

crontab -l

Para revisar el log:

tail -f ~/respaldos/cron.log

Para observar la creación de archivos:

watch -n 5 'ls -lh ~/respaldos | tail'

Para salir:

Ctrl + C

La prueba produjo respaldos automáticamente, demostrando que Cron ejecutaba correctamente el script.

---

## 8. Problema de ejecuciones simultáneas

Durante la prueba se detectó que un respaldo tardaba más de un minuto.

Esto provocó varias ejecuciones simultáneas y un aumento importante en el uso del disco.

Para comprobar procesos:

pgrep -af respaldar.sh

Para detenerlos:

pkill -f respaldar.sh

Para comprobar espacio:

df -h

Para localizar archivos temporales:

find ~/respaldos -type f -name "*.tmp" -ls

Para eliminarlos:

rm -f ~/respaldos/*.tmp

---

## 9. Configuración definitiva de Cron

Para evitar respaldos simultáneos se utilizó flock.

Para comprobar su ubicación:

command -v flock

Resultado:

/usr/bin/flock

La configuración definitiva es:

30 2 * * * /usr/bin/flock -n /tmp/chamilo-respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1

Para editar:

crontab -e

Para comprobar:

crontab -l

El respaldo se ejecuta todos los días a las 02:30.

flock evita iniciar otro respaldo mientras existe uno en proceso.

---

## 10. Justificación de la frecuencia

Se eligió un respaldo diario porque la plataforma de capacitación no tendrá modificaciones constantes durante todo el día.

En el peor caso podrían perderse hasta aproximadamente 24 horas de cambios.

Durante periodos con muchas inscripciones, cursos nuevos o carga masiva de información sería recomendable aumentar la frecuencia.

---

## 11. Preparación de la restauración

Antes de realizar una restauración destructiva se comprobó nuevamente la integridad.

Base de datos:

gzip -t ~/respaldos/chamilo-bd-2026-10-30_0624.sql.gz && echo "BD OK"

Archivos:

tar -tzf ~/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz > /dev/null && echo "ARCHIVOS OK"

También se comprobó Chamilo:

curl -I http://127.0.0.1:8081

Resultado:

HTTP/1.1 200 OK

---

## 12. Eliminación controlada de los datos

Para demostrar que los respaldos permiten recuperar el sistema se eliminaron los contenedores y volúmenes:

cd ~/proyecto-eif431o/docker

docker compose down -v

Para comprobar que no quedaran contenedores:

docker compose ps

Para comprobar los volúmenes:

docker volume ls | grep chamilo

---

## 13. Restauración de la base de datos

Primero se levantó MariaDB:

cd ~/proyecto-eif431o/docker

docker compose up -d bd

Para comprobar su estado:

docker compose ps

Se dieron permisos al script:

cd ~/proyecto-eif431o

chmod +x backups/restaurar.sh

Se restauró la base:

./backups/restaurar.sh ~/respaldos/chamilo-bd-2026-10-30_0624.sql.gz

Resultado:

BD restaurada: /home/server/respaldos/chamilo-bd-2026-10-30_0624.sql.gz

Después se contaron las tablas:

cd ~/proyecto-eif431o/docker

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'

Resultado:

239

Esto demostró que la estructura de la base fue recuperada correctamente.

---

## 14. Restauración de los archivos de Chamilo

Se dieron permisos al script:

cd ~/proyecto-eif431o

chmod +x backups/restaurar-archivos.sh

Luego:

./backups/restaurar-archivos.sh ~/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz

Resultado:

Archivos restaurados: /home/server/respaldos/chamilo-archivos-2026-10-30_0624.tar.gz

Para comprobar los servicios:

cd ~/proyecto-eif431o/docker

docker compose ps

Finalmente:

curl -I http://127.0.0.1:8081

Resultado:

HTTP/1.1 200 OK

Esto demostró que Chamilo pudo recuperarse después de eliminar completamente sus datos persistentes.
## 14.1 Prueba de restauración por punto en el tiempo

Para comprobar que el respaldo realmente devuelve el sistema al estado del momento en que fue creado, se realizó una prueba con dos usuarios.

Primero se creó:

respaldo_a

Se comprobó su existencia en MariaDB.

Luego se generó un nuevo respaldo:

chamilo-bd-2026-10-31_0501.sql.gz

y su correspondiente respaldo de archivos.

Después del respaldo se creó:

respaldo_b

Antes de realizar la restauración existían ambos usuarios:

respaldo_a

respaldo_b

Después se eliminaron los volúmenes de prueba:

cd ~/proyecto-eif431o/docker

docker compose down -v

Se volvió a levantar MariaDB:

docker compose up -d bd

Se esperó hasta que MariaDB apareciera healthy:

docker compose ps

Luego se restauró el respaldo creado después de respaldo_a y antes de respaldo_b:

cd ~/proyecto-eif431o

./backups/restaurar.sh ~/respaldos/chamilo-bd-2026-10-31_0501.sql.gz

Después se restauraron los archivos de Chamilo.

Al verificar nuevamente la base de datos se obtuvo:

respaldo_a

El usuario respaldo_b ya no apareció.

También se comprobaron:

239 tablas

y:

HTTP/1.1 200 OK

Esto demuestra que la restauración regresó correctamente al estado existente en el momento exacto del respaldo.
---

## 15. Copia externa de los respaldos

Se configuró una copia externa hacia una máquina Linux Mint.

IP de Mint:

192.168.50.101

Usuario:

server

En Mint se instaló SSH:

sudo apt update

sudo apt install openssh-server -y

sudo systemctl enable --now ssh

Para crear la carpeta destino:

mkdir -p ~/respaldos-losangeles

Desde el servidor principal se creó una clave exclusiva para la automatización:

ssh-keygen -t ed25519 -f ~/.ssh/respaldo_cron_ed25519 -N ""

La clave pública se copió hacia Mint:

ssh-copy-id -i ~/.ssh/respaldo_cron_ed25519.pub server@192.168.50.101

Se comprobó que el acceso funciona sin contraseña:

ssh -o BatchMode=yes -i ~/.ssh/respaldo_cron_ed25519 server@192.168.50.101 'echo "SSH AUTOMATICO OK"'

Resultado:

SSH AUTOMATICO OK

Para realizar una copia manual:

rsync -av -e "ssh -i ~/.ssh/respaldo_cron_ed25519" ~/respaldos/ server@192.168.50.101:~/respaldos-losangeles/

## 16. Automatización de la copia externa

Después del respaldo local de las 02:30 se configuró una segunda tarea Cron.

La copia externa se ejecuta diariamente a las 03:00:

0 3 * * * /usr/bin/rsync -av -e "ssh -i $HOME/.ssh/respaldo_cron_ed25519" $HOME/respaldos/ server@192.168.50.101:~/respaldos-losangeles/ >> $HOME/respaldos/rsync.log 2>&1

Para comprobar ambas tareas:

crontab -l

Las tareas finales son:

30 2 * * * /usr/bin/flock -n /tmp/chamilo-respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1

0 3 * * * /usr/bin/rsync -av -e "ssh -i $HOME/.ssh/respaldo_cron_ed25519" $HOME/respaldos/ server@192.168.50.101:~/respaldos-losangeles/ >> $HOME/respaldos/rsync.log 2>&1

## 16.1 Verificación de la copia externa

En Linux Mint:

ls -lh ~/respaldos-losangeles/

Se comprobó que los respaldos llegaron correctamente a la máquina externa.

La copia externa permite recuperar la plataforma incluso si se pierde completamente la VM principal..

---

## 17. Estado de los servicios

Para revisar el proyecto:

cd ~/proyecto-eif431o/docker

docker compose ps

Servicios esperados:

bd

chamilo

balanceador

MariaDB y Chamilo deben aparecer en estado healthy.

---

## 18. Configuración final del balanceador

Durante la instalación se publicó temporalmente el puerto 8081:

ports:
  - "8081:80"

Después se regresó a la configuración final:

ports:
  - "127.0.0.1:8081:80"

Para aplicar:

cd ~/proyecto-eif431o/docker

docker compose up -d --force-recreate balanceador

Para comprobar:

docker compose ps

Resultado esperado:

127.0.0.1:8081->80/tcp

Esto permite que únicamente el servidor acceda directamente al balanceador y que Nginx funcione como punto de entrada HTTPS.

---

## 19. Limitaciones y mejoras

FTP simple transmite las credenciales y datos sin cifrar.

En producción sería recomendable utilizar:

- SFTP
- FTPS

También sería recomendable:

- almacenar una segunda copia externa;
- utilizar almacenamiento remoto;
- monitorear el espacio disponible;
- generar alertas cuando falle un respaldo;
- evitar respaldos simultáneos mediante flock;
- realizar pruebas periódicas de restauración.

---

## Resultado de las pruebas

Las pruebas permitieron comprobar:

- respaldo manual de MariaDB;
- respaldo del volumen de Chamilo;
- verificación de integridad;
- ejecución automática mediante Cron;
- prevención de ejecuciones simultáneas;
- restauración completa de MariaDB;
- recuperación de 239 tablas;
- restauración de archivos de Chamilo;
- recuperación funcional de la plataforma;
- respuesta HTTP 200;
- copia externa mediante SSH y rsync;
- verificación de los respaldos en otra máquina.

Por lo tanto, el procedimiento de respaldo y recuperación del proyecto quedó probado de forma práctica.
