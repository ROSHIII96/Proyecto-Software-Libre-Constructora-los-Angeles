# Proyecto EIF431O — Constructora Los Ángeles (Chamilo LMS) — Equipo Kernel Panic

Plataforma de capacitación en seguridad laboral basada en Chamilo LMS, con registro de usuarios, progreso, evaluaciones, alta disponibilidad de la aplicación, respaldos automáticos y recuperación de datos.

## Arquitectura general

La arquitectura final del proyecto utiliza:

Cliente Linux Mint → DNS BIND9 → Nginx HTTPS del servidor → Balanceador nginx en Docker → Chamilo → MariaDB

El balanceador Docker escucha únicamente de forma local en:

127.0.0.1:8081

MariaDB y los contenedores de Chamilo no publican directamente sus puertos hacia la red.

## Estructura del proyecto

| Carpeta | Contenido | Responsable |
|---|---|---|
| `docker/` | Docker Compose, imagen de Chamilo, balanceador y MariaDB | Integrantes 2, 3 y 4 |
| `dns/` | Configuración BIND9 y zona `losangeles.internal` | Integrante 1 |
| `ftp/` | Configuración vsftpd y creación de usuarios FTP | Integrante 5 |
| `backups/` | Scripts de respaldo y restauración | Integrante 5 con Integrante 4 |
| `docs/` | Documentación, evidencias, decisiones, versiones y guías | Todo el equipo; consolida Integrante 5 |

## Servicios principales

- Chamilo LMS 1.11.40
- PHP 8.3
- MariaDB 11.8
- nginx 1.30-alpine
- BIND9
- vsftpd
- Docker Engine
- Docker Compose

## Despliegue general

1. Clonar el repositorio:

git clone https://github.com/ROSHIII96/Proyecto-Software-Libre-Constructora-los-Angeles.git ~/proyecto-eif431o

2. Entrar al proyecto:

cd ~/proyecto-eif431o

3. Configurar DNS, HTTPS y Nginx del servidor siguiendo la guía del Integrante 1.

4. Crear el archivo de variables:

cd docker

cp .env.example .env

5. Completar las variables del archivo `.env` sin subir credenciales al repositorio.

6. Construir y levantar la plataforma:

docker compose up -d --build

7. Verificar los servicios:

docker compose ps

8. Instalar y configurar Chamilo.

9. Para alta disponibilidad, levantar dos réplicas de Chamilo:

docker compose up -d --scale chamilo=2

10. Configurar FTP y respaldos siguiendo la guía del Integrante 5.

## Respaldos

Los respaldos locales se guardan en:

~/respaldos

Se generan automáticamente todos los días a las 02:30.

La copia externa hacia la máquina Linux Mint se realiza automáticamente a las 03:00 mediante SSH y rsync.

Los procedimientos completos de respaldo y restauración se encuentran en:

docs/respaldos.md

## Recuperación

Se realizó una prueba real de recuperación eliminando los volúmenes persistentes y restaurando:

- la base de datos MariaDB;
- los archivos persistentes de Chamilo.

Después de la restauración se comprobaron 239 tablas y la plataforma volvió a responder HTTP 200.

También se realizó una prueba con dos usuarios:

- `respaldo_a`, creado antes del respaldo;
- `respaldo_b`, creado después del respaldo.

Después de restaurar el respaldo, `respaldo_a` volvió correctamente y `respaldo_b` no apareció, demostrando que la restauración regresó al estado exacto del momento respaldado.

## Copia externa

Los respaldos se copian mediante rsync hacia una segunda máquina Linux ubicada en la red interna.

Esto permite recuperar la plataforma incluso si se pierde completamente la VM principal.

## Seguridad

No se deben subir al repositorio:

- `.env`
- contraseñas
- claves privadas SSH
- archivos `.sql`
- archivos `.sql.gz`
- archivos `.tar.gz`
- archivos `.zip`

Las credenciales utilizadas por los scripts se obtienen desde variables de entorno o se solicitan de forma interactiva.

## Limitaciones

La arquitectura protege ante la caída de una réplica de Chamilo mediante balanceo entre instancias.

Sin embargo, existen puntos únicos de fallo:

- Nginx del servidor;
- MariaDB;
- la máquina virtual principal.

Si se pierde completamente la VM principal, la recuperación debe realizarse manualmente utilizando la copia externa de los respaldos.

## Documentación

La documentación del proyecto se encuentra dentro de `docs/`, incluyendo:

- `respaldos.md`
- `inventario-red.md`
- `decisiones.md`
- `versiones.md`
- `guias/`
- `evidencias/`

El manual completo de instalación se encuentra en:

`docs/instalacion.md`
