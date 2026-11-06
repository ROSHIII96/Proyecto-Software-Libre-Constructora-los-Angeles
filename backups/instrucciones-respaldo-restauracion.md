# Instrucciones de restauración de respaldos

## Proyecto Constructora Los Ángeles — Chamilo LMS

Esta guía explica cómo restaurar la base de datos MariaDB y los archivos persistentes de Chamilo mediante los scripts del proyecto.

IMPORTANTE:
La restauración puede reemplazar información actual.
Las pruebas destructivas deben realizarse únicamente en un entorno de pruebas.
Nunca ejecutar docker compose down -v en el servidor definitivo.

## 1. Scripts utilizados

El proyecto contiene dos scripts de restauración:

backups/restaurar.sh
backups/restaurar-archivos.sh

Ambos se encuentran en:

~/proyecto-eif431o/backups/

### restaurar.sh

Este script restaura la base de datos MariaDB.

Permite recuperar:
- Usuarios registrados.
- Cursos.
- Inscripciones.
- Calificaciones.
- Configuraciones almacenadas en MariaDB.

Utiliza un respaldo comprimido con extensión:

.sql.gz

### restaurar-archivos.sh

Este script restaura los archivos persistentes de Chamilo.

Permite recuperar los documentos, materiales y demás archivos guardados en el volumen:

chamilo_app

Utiliza un respaldo comprimido con extensión:

.tar.gz

El script detiene temporalmente los servicios correspondientes, restaura el contenido del volumen y vuelve a levantar los servicios.

## 2. Comprobar los respaldos disponibles

En el servidor principal ejecutar:

ls -lh ~/respaldos/

Los archivos tienen nombres similares a:

chamilo-bd-2026-10-31_0501.sql.gz

chamilo-archivos-2026-10-31_0501.tar.gz

Es importante seleccionar un respaldo de base de datos y otro de archivos correspondientes al mismo momento.

## 3. Comprobar la integridad de los respaldos

Para verificar el archivo de MariaDB:

gzip -t ~/respaldos/NOMBRE-RESPALDO.sql.gz

Para verificar el respaldo de archivos:

tar -tzf ~/respaldos/NOMBRE-ARCHIVOS.tar.gz > /dev/null

Si ambos comandos terminan sin errores, los archivos comprimidos pasaron las pruebas básicas de integridad.

Esto no sustituye una prueba real de restauración.

## 4. Verificar Docker

Entrar al directorio Docker:

cd ~/proyecto-eif431o/docker

Verificar los servicios:

docker compose ps

Los servicios del proyecto son:

bd
chamilo
balanceador

Para realizar la restauración, primero se necesita que MariaDB esté funcionando correctamente.

## 5. Levantar MariaDB

Ejecutar:

cd ~/proyecto-eif431o/docker

docker compose up -d bd

Comprobar:

docker compose ps

Esperar hasta que MariaDB aparezca con estado:

healthy

IMPORTANTE:
No iniciar la restauración de la base de datos mientras MariaDB esté iniciando.

## 6. Restaurar la base de datos

Volver a la raíz del proyecto:

cd ~/proyecto-eif431o

Dar permiso de ejecución:

chmod +x backups/restaurar.sh

Ejecutar el script utilizando el nombre del respaldo seleccionado:

./backups/restaurar.sh ~/respaldos/NOMBRE-RESPALDO.sql.gz

Ejemplo utilizado durante las pruebas:

./backups/restaurar.sh ~/respaldos/chamilo-bd-2026-10-31_0501.sql.gz

El script descomprime el respaldo SQL e importa la información en MariaDB mediante Docker Compose.

Resultado esperado:

BD restaurada: /home/server/respaldos/NOMBRE-RESPALDO.sql.gz

## 7. Verificar la base de datos restaurada

Entrar a Docker:

cd ~/proyecto-eif431o/docker

Comprobar las tablas:

docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'

Durante la prueba realizada se recuperaron:

239 tablas

La cantidad puede cambiar si la plataforma incorpora nuevas tablas.

## 8. Restaurar los archivos de Chamilo

Regresar a la raíz del proyecto:

cd ~/proyecto-eif431o

Dar permiso de ejecución:

chmod +x backups/restaurar-archivos.sh

Ejecutar la restauración utilizando el archivo seleccionado:

./backups/restaurar-archivos.sh ~/respaldos/NOMBRE-ARCHIVOS.tar.gz

Ejemplo utilizado durante las pruebas:

./backups/restaurar-archivos.sh ~/respaldos/chamilo-archivos-2026-10-31_0501.tar.gz

El script recupera los archivos almacenados en el volumen persistente chamilo_app.

Durante el proceso, la plataforma puede quedar temporalmente fuera de servicio.

## 9. Levantar los servicios

Una vez terminada la restauración:

cd ~/proyecto-eif431o/docker

docker compose up -d

Comprobar:

docker compose ps

MariaDB y Chamilo deben aparecer en estado healthy.

El balanceador también debe estar funcionando.

## 10. Comprobar el funcionamiento de Chamilo

Desde el servidor principal ejecutar:

curl -I http://127.0.0.1:8081

Resultado esperado:

HTTP/1.1 200 OK

También se recomienda acceder desde el navegador y comprobar:

- Inicio de sesión.
- Usuarios existentes.
- Cursos registrados.
- Documentos de los cursos.
- Funcionamiento general de la plataforma.

La respuesta HTTP 200 por sí sola no garantiza que todos los datos estén correctos.

## 11. Prueba realizada con dos usuarios

Durante las pruebas del proyecto se realizó una restauración controlada.

Paso 1:
Se creó el usuario respaldo_a.

Paso 2:
Se generó un respaldo de MariaDB y de los archivos de Chamilo.

Paso 3:
Se creó un segundo usuario llamado respaldo_b.

Paso 4:
Se simuló la pérdida de los datos persistentes en la máquina de pruebas.

Paso 5:
Se restauró el respaldo generado antes de crear respaldo_b.

Resultados:

- respaldo_a fue recuperado.
- respaldo_b no apareció.
- Se recuperaron 239 tablas.
- Chamilo volvió a funcionar.
- El servicio respondió HTTP 200.

Esto permitió comprobar que el respaldo recuperaba la información correspondiente al momento en que fue generado.

## 12. Restauración después de una pérdida de datos

En un entorno de pruebas, después de simular una pérdida de los volúmenes, el procedimiento consiste en:

1. Levantar MariaDB.
2. Esperar a que esté healthy.
3. Restaurar el respaldo SQL.
4. Restaurar el respaldo de archivos.
5. Levantar los servicios.
6. Verificar las tablas.
7. Comprobar usuarios y cursos.
8. Verificar el acceso desde el navegador.

La restauración debe utilizar respaldos compatibles y correspondientes al mismo momento.

IMPORTANTE:
No eliminar los volúmenes del servidor definitivo para realizar una demostración.

## 13. Copia externa de los respaldos

Los respaldos también se copiaron hacia una máquina Linux Mint.

Dirección IP:

192.168.50.101

Carpeta destino:

~/respaldos-losangeles/

La transferencia se realiza mediante SSH y rsync.

Para revisar los archivos desde Mint:

ls -lh ~/respaldos-losangeles/

Si el servidor principal se pierde, los respaldos externos pueden copiarse a un servidor reconstruido para ejecutar los procedimientos de recuperación.

## 14. Problemas frecuentes

Problema:
MariaDB no está disponible.

Solución:
Ejecutar docker compose ps y esperar hasta que el contenedor bd esté healthy.

Problema:
El archivo de respaldo no existe.

Solución:
Revisar los nombres disponibles con:

ls -lh ~/respaldos/

Problema:
El respaldo está dañado.

Solución:
Comprobar con gzip -t o tar -tzf y seleccionar una copia válida.

Problema:
Chamilo responde, pero faltan documentos.

Solución:
Comprobar que también se restauró el respaldo de archivos correspondiente.

Problema:
La base de datos funciona, pero Chamilo no inicia.

Solución:
Revisar el estado y los logs:

cd ~/proyecto-eif431o/docker

docker compose ps

docker compose logs --tail=50 chamilo

## 15. Conclusión

El proyecto dispone de dos scripts complementarios.

restaurar.sh:
Recupera la información almacenada en MariaDB.

restaurar-archivos.sh:
Recupera los archivos persistentes de Chamilo.

Para una recuperación completa es necesario restaurar ambos componentes y verificar que la plataforma funcione correctamente.

Las pruebas realizadas permitieron confirmar la recuperación de usuarios, tablas y funcionamiento general de Chamilo.
