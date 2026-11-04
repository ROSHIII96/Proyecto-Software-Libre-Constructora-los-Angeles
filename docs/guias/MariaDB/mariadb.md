## Comandos del integrante 4

Para lograr visualizar el estado actual de `docker/docker-compose.yml` se usa el comando

```bash
cd ~/proyecto-eif431o/docker
nano docker-compose.yml
```

Seguidamente se hacen las pruebas de humo, utilizando los archivos de docker elavorados anteriormente


```bash
cd ~/proyecto-eif431o/docker
docker compose up -d bd
docker compose ps
docker compose logs bd | tail -20
```
Si el estado del contenedor es `healthy` y en el log se marca el puerto con `ready for connections` significa que ya todo esta listo.

Para ingresar a las bases de datos se usa el comando
```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT VERSION(); SHOW DATABASES;"'
```


Ahora que el contenedor esta contruido, se configura con respecto al proyecto y su seguridad

Se le dan los permisos minimos.

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW GRANTS FOR chamilo_user@\"%\"; SELECT user,host FROM mysql.user;"'
```

Para semostrar las dos capas de acceso

```bash
# Capa 1: red. Desde el host NO debe haber puerto 3306 publicado
ss -tlnp | grep 3306            # sin resultados
docker compose port bd 3306     # sin mapeo
# Capa 2: permisos. El usuario de la app no puede tocar otras bases
docker compose exec bd sh -c 'mariadb -uchamilo_user -p"$MARIADB_PASSWORD" -e "SHOW DATABASES;"'
```

Una ves con datos agregados, se pueden hacer pruebas de persistencia y durabilidad.

```bash
docker volume ls | grep chamilo_datos_bd
docker compose restart bd                    # reinicio ordenado: datos intactos
docker kill chamilo-bd-1                     # muerte abrupta; restart: unless-stopped lo levanta
docker compose ps
docker compose logs bd | tail -30            # busque "crash recovery" / "ready for connections"
```

Para ver los datos se utiliza el comando:
```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" chamilo -e "SELECT COUNT(*) FROM user; SELECT COUNT(*) FROM course;"'
```

Para lograr hacer un monitoreo en las bases de datos.

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW PROCESSLIST; SHOW STATUS LIKE \"Threads_connected\"; SHOW STATUS LIKE \"Uptime\";"'
docker system df -v | grep chamilo_datos_bd
docker compose logs --tail 50 bd
```

Para respladar y restaurar se utilizan los archivos de `backups/respaldar.sh` y `restaurar.sh` respectivamente.