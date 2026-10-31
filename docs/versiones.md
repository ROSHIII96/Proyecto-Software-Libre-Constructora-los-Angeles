# Versiones utilizadas en el proyecto

Las versiones principales del proyecto deben mantenerse estables entre los integrantes.

Si se cambia una versión importante, el cambio debe comunicarse al equipo y registrarse en `docs/decisiones.md`.

| Componente | Versión utilizada | Dónde se define o verifica | Estado |
|---|---|---|---|
| Ubuntu Server | Según VM del integrante / servidor definitivo | `lsb_release -a` | verificar en servidor definitivo |
| Docker Engine | Versión instalada en el servidor | `docker version` | funcionando |
| Docker Compose | Versión instalada en el servidor | `docker compose version` | funcionando |
| Git | Versión instalada en el servidor | `git --version` | funcionando |
| Chamilo LMS | 1.11.40 | `docker/.env` | probado y funcionando |
| PHP | 8.3 | imagen utilizada para Chamilo | probado y funcionando |
| MariaDB | 11.8 | `docker-compose.yml` | probado y funcionando |
| nginx balanceador | 1.30-alpine | `docker-compose.yml` | probado y funcionando |
| Nginx del servidor | paquete instalado mediante APT | `nginx -v` | arquitectura final |
| BIND9 | paquete instalado mediante APT | `named -v` | utilizado para DNS |
| vsftpd | paquete instalado mediante APT | `vsftpd -v` | probado y funcionando |
| OpenSSH Server | paquete instalado mediante APT | `sshd -V` / paquete instalado | utilizado para administración y respaldos |
| rsync | paquete del sistema | `rsync --version` | probado y funcionando |

## Imágenes principales de Docker

### MariaDB

Imagen utilizada:

mariadb:11.8

MariaDB almacena la información de Chamilo en el volumen persistente:

chamilo_datos_bd

Durante las pruebas de restauración se recuperaron correctamente 239 tablas.

### nginx

Imagen utilizada para el balanceador:

nginx:1.30-alpine

El balanceador distribuye las solicitudes hacia las réplicas de Chamilo.

El puerto debe publicarse únicamente en:

127.0.0.1:8081

### Chamilo

Versión utilizada:

1.11.40

Fecha de la versión utilizada:

24/06/2026

Archivo utilizado:

chamilo-1.11.40.zip

URL de descarga configurada en el proyecto:

https://github.com/chamilo/chamilo-lms/releases/download/v1.11.40/chamilo-1.11.40.zip

SHA-256 registrado:

1cf4bf2cc7bae1ef1a1eff643235db1d552f78ddf4b6dd1e2d2dac9868679439

El archivo fue verificado previamente mediante:

sha256sum

## Versiones alternativas consideradas

Durante el desarrollo se contemplaron algunas alternativas en caso de problemas de compatibilidad.

PHP:

8.3

Alternativa considerada:

7.4

MariaDB:

11.8

Alternativa considerada:

10.11

Las alternativas no fueron necesarias porque las versiones principales funcionaron correctamente durante las pruebas.

## Política de versiones

No utilizar imágenes con la etiqueta:

latest

Las versiones deben escribirse explícitamente en `docker-compose.yml`, `.env` o los archivos correspondientes.

Esto permite que todos los integrantes trabajen con versiones conocidas y reduce el riesgo de que una actualización automática rompa el proyecto.

## Comandos para comprobar versiones

Docker:

docker version

Docker Compose:

docker compose version

Git:

git --version

Nginx:

nginx -v

BIND9:

named -v

vsftpd:

vsftpd -v

rsync:

rsync --version

Sistema operativo:

lsb_release -a

## Nota

Las versiones de paquetes instalados mediante APT pueden variar ligeramente según la versión de Ubuntu utilizada.

Antes de la entrega final se recomienda ejecutar los comandos anteriores en el servidor definitivo y registrar las versiones exactas utilizadas.
