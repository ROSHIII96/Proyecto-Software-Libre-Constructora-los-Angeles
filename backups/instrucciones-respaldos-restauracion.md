# Instrucciones de respaldos y restauración

# Proyecto Constructora Los Ángeles — Chamilo LMS

Esta guía explica cómo **crear, comprobar y restaurar** respaldos de la base de datos MariaDB y de los archivos persistentes de Chamilo mediante los scripts del proyecto.

**Equipo:** Integrante 5 (respaldos), con apoyo del Integrante 4 (base de datos).

> **Advertencia:** La restauración puede sobrescribir información actual. Realice las pruebas destructivas **solo en una máquina de pruebas**. No ejecute `docker compose down -v` en el servidor definitivo, porque puede eliminar los datos persistentes.

## 1. Requisitos previos

Antes de crear un respaldo deben existir:

- Ubuntu Server con Docker Engine y Docker Compose funcionando.
- Proyecto ubicado en `~/proyecto-eif431o`.
- Servicios Docker `bd`, `chamilo` y `balanceador` configurados.
- Instalación de Chamilo con datos para respaldar.
- Scripts `backups/respaldar.sh`, `backups/restaurar.sh` y `backups/restaurar-archivos.sh` incluidos en el repositorio.

Comprobar los servicios desde el **servidor principal**:

```bash
cd ~/proyecto-eif431o/docker
docker compose ps
```

La base de datos `bd` y Chamilo deben encontrarse operativos, idealmente en estado `healthy`.

## 2. ¿Qué hace cada script?

| Script | Función | Archivo utilizado |
|---|---|---|
| `backups/respaldar.sh` | Genera respaldos de MariaDB y del volumen persistente `chamilo_app`. | Produce `.sql.gz` y `.tar.gz` |
| `backups/restaurar.sh` | Importa en MariaDB el contenido de un respaldo SQL comprimido. | Lee `.sql.gz` |
| `backups/restaurar-archivos.sh` | Recupera los archivos persistentes de Chamilo en su volumen Docker. | Lee `.tar.gz` |

**Diferencia:** la base de datos contiene usuarios, cursos, inscripciones y demás registros; el volumen de archivos contiene documentos y otros archivos persistentes. Para recuperar la plataforma es necesario considerar **ambas partes**.

## 3. Crear los respaldos por primera vez

Desde **Ubuntu Server**, entrar al proyecto y dar permisos al script:

```bash
cd ~/proyecto-eif431o
chmod +x backups/respaldar.sh
```

Ejecutar el respaldo manual:

```bash
./backups/respaldar.sh
```

El script genera los respaldos en:

```text
~/respaldos/
```

Se esperan dos archivos con la **misma fecha y hora**, por ejemplo (nombres ilustrativos):

```text
chamilo-bd-AAAA-MM-DD_HHMM.sql.gz
chamilo-archivos-AAAA-MM-DD_HHMM.tar.gz
```

Para ver los nombres reales:

```bash
ls -lh ~/respaldos/
```

Para ver el registro de respaldo:

```bash
tail -n 20 ~/respaldos/respaldo.log
```

**Importante:** compruebe que ambos archivos existen y que el script terminó sin errores antes de continuar.

## 4. Verificar integridad de los respaldos

Seleccione los **nombres reales** que aparezcan en `ls -lh ~/respaldos/` y sustitúyalos en los comandos siguientes.

Comprobar la compresión del respaldo de la base:

```bash
gzip -t ~/respaldos/NOMBRE-REAL-BD.sql.gz && echo "BD OK"
```

Comprobar la compresión y lectura del respaldo de archivos:

```bash
tar -tzf ~/respaldos/NOMBRE-REAL-ARCHIVOS.tar.gz > /dev/null && echo "ARCHIVOS OK"
```

Si aparece `BD OK` y `ARCHIVOS OK`, los archivos pasaron la **comprobación básica de integridad**. Esto no sustituye una restauración de prueba.

## 5. Preparar la restauración

> **Antes de restaurar:** confirme que eligió el par correcto de respaldos y que cuenta con una copia segura de cualquier dato actual que deba conservar. No restaure un respaldo antiguo directamente sobre una instancia que tiene información nueva importante.

Entrar al directorio Docker:

```bash
cd ~/proyecto-eif431o/docker
```

Levantar la base de datos si está detenida:

```bash
docker compose up -d bd
```

Comprobar su estado:

```bash
docker compose ps
```

**Esperar hasta que `bd` aparezca en estado `healthy`.** Si se ejecuta el restaurador antes de que MariaDB termine de iniciar, la conexión puede fallar.

## 6. Restaurar la base de datos MariaDB

Volver a la raíz del proyecto y comprobar permisos:

```bash
cd ~/proyecto-eif431o
chmod +x backups/restaurar.sh
```

Ejecutar usando **el nombre real** del archivo de respaldo seleccionado:

```bash
./backups/restaurar.sh ~/respaldos/NOMBRE-REAL-BD.sql.gz
```

Ejemplo del respaldo empleado en una prueba del proyecto (úselo solo si ese archivo existe en su equipo):

```bash
./backups/restaurar.sh ~/respaldos/chamilo-bd-2026-10-31_0501.sql.gz
```

El script descomprime el archivo `.sql.gz` e importa sus instrucciones a la base MariaDB mediante Docker Compose. Espere la confirmación de la restauración y revise cualquier mensaje de error.

## 7. Verificar la base restaurada

Desde el directorio Docker:

```bash
cd ~/proyecto-eif431o/docker
```

Contar las tablas de la base `chamilo`:

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'
```

En nuestra prueba de recuperación se obtuvieron **239 tablas**. El número puede ser diferente en otra instalación o después de cambios del sistema.

Para verificar usuarios específicos, si existen en su respaldo:

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE" -e "SELECT id, username FROM user WHERE username IN ('\''respaldo_a'\'','\''respaldo_b'\'');"'
```

## 8. Restaurar los archivos persistentes de Chamilo

Volver al proyecto y dar permisos:

```bash
cd ~/proyecto-eif431o
chmod +x backups/restaurar-archivos.sh
```

Ejecutar con el respaldo de archivos **correspondiente al mismo momento** que la base restaurada:

```bash
./backups/restaurar-archivos.sh ~/respaldos/NOMBRE-REAL-ARCHIVOS.tar.gz
```

Ejemplo de la prueba (solo si el archivo existe):

```bash
./backups/restaurar-archivos.sh ~/respaldos/chamilo-archivos-2026-10-31_0501.tar.gz
```

Este script restaura el contenido del volumen Docker `chamilo_app`. Durante el proceso se pueden detener temporalmente servicios de la aplicación. No interrumpa la operación a mitad de la extracción.

## 9. Encender y comprobar Chamilo

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d
docker compose ps
```

Comprobar la respuesta del balanceador **desde el servidor principal**:

```bash
curl -I http://127.0.0.1:8081
```

Una respuesta `HTTP/1.1 200 OK` indica que el servicio web responde, pero **no demuestra por sí sola** que todos los registros y documentos estén correctos.

En el navegador, entrar a la dirección configurada para el proyecto:

```text
https://capacitacion.losangeles.internal
```

Comprobar inicio de sesión, usuarios, cursos, documentos y funcionamiento general. El dominio necesita DNS y el proxy HTTPS correctamente configurados.

## 10. Prueba real realizada: usuario A y usuario B

La prueba de recuperación se realizó **en una máquina de pruebas**:

1. Se creó el usuario `respaldo_a`.
2. Se generó el par de respaldos de MariaDB y archivos.
3. Se creó el usuario `respaldo_b` después del respaldo.
4. Se simuló una pérdida de datos persistentes **solo en el entorno de pruebas**.
5. Se restauró el respaldo generado antes de crear `respaldo_b`.

Resultados comprobados:

- Se recuperó `respaldo_a`.
- `respaldo_b` no apareció después de restaurar.
- Se recuperaron 239 tablas.
- Chamilo volvió a responder HTTP 200.

Esto mostró que la recuperación regresó al estado guardado cuando se creó el respaldo. **No repita la eliminación de volúmenes en el servidor definitivo.**

## 11. Copia externa en Linux Mint

En el proyecto se configuró una segunda copia mediante SSH y `rsync` hacia Linux Mint:

```text
Servidor de respaldos: 192.168.50.101
Usuario: server
Carpeta destino: ~/respaldos-losangeles/
```

Desde **Mint** se puede comprobar:

```bash
ls -lh ~/respaldos-losangeles/
```

Si el servidor principal falla completamente, primero se debe reconstruir la infraestructura, copiar los archivos de respaldo disponibles desde Mint al nuevo servidor y después seguir la restauración de base y archivos.

## 12. Problemas frecuentes

**MariaDB no está lista:**

```bash
cd ~/proyecto-eif431o/docker
docker compose ps
```

Espere que el servicio `bd` muestre `healthy`.

**No se encuentra el archivo:**

```bash
ls -lh ~/respaldos/
```

Utilice el nombre exacto del archivo existente.

**El archivo comprimido da error:** vuelva a comprobarlo con `gzip -t` o `tar -tzf`; busque otra copia válida si la compresión está dañada.

**Chamilo abre, pero faltan documentos:** compruebe que restauró el archivo `.tar.gz` correspondiente a la misma fecha del respaldo SQL.

**Chamilo no inicia:**

```bash
cd ~/proyecto-eif431o/docker
docker compose ps
docker compose logs --tail=50 chamilo
```

## 13. Conclusión

El procedimiento comienza **creando los respaldos**, continúa **verificando su integridad** y, solamente si se necesita recuperar la plataforma, utiliza los scripts `restaurar.sh` y `restaurar-archivos.sh`.

Los dos respaldos son complementarios: uno recupera los registros en MariaDB y el otro los archivos persistentes de Chamilo. Una restauración se considera completada después de verificar tanto los datos como el funcionamiento de la plataforma.
