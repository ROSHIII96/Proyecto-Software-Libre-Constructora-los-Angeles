## Elementos de `docker/docker-compose.yml`

Este archivo es el responsable de la contruccion de los contenedores para la base de datos. El mismo esta dibidido en varios elementos.

| Elemento | Para qué sirve |
|---|---|
| `image: mariadb:11.8` | Versión a utilizar del gestos de base de datos `MariaDB`, se utiliza la version 11.8 como version fija. |
| `command` con `utf8mb4` | Con este elemento, la base de datos es capas de guardar caracteres, que son catalogados como **especiales**, dejando poder usar tildes, ñ, ü, etc  |
| `environment` (`MARIADB...`) | Crea la base y el usuario `chamilo_user` en el **primer** arranque |
| `volumes: chamilo_datos_bd:/var/lib/mysql` | Crea y almacena todos los datos en volumenes con el fin de no comprometer los datos en el contenedor |
| `healthcheck` | Docker marca `healthy` solo cuando MariaDB responde; Chamilo espera ese estado (`depends_on: service_healthy`) |
| sin `ports` | La base **no** es alcanzable desde la red; solo por el DNS interno (`bd`) |
| `restart: unless-stopped` | En caso de que el proceso muera, este se puede levantar solo. |

## MARIADB_PASSWORD

Este dato en las variables de entorno (`.env`) es utilizado una sola ves, y esa es cuando el contenedor enciende por primera ves, por ende, encaso de que el .env sea cambiado, este no afectara en el arranque.

## Versiones y su importancia

Con cada version, las reglas de negocio de los diferentes paquetes y librerias cambian, en muchos casos, tambien sus dependencias. debido a esto se establecio la version de MariaDB.

## Capas y su seguridad

Existen dos capas aseguradas en el sistema de bases de datos, la de red que tiene unicamente el puerto 3306 a utilizar.

Por otro lado exiete la seguridad de permisos, que hace que los usuarios solo ppuedan usar la base de datos a la que tiene acceso la plataforma.

## Respaldos

La plataforma esta asegurada a nivel de datos en su totalidad, asegurando con un respaldo automatico a las 2:30 AM de cada dia.