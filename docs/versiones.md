# Versiones fijadas (todos usamos EXACTAMENTE estas)
Cambiar una versión requiere avisar a los cinco y anotarlo en `decisiones.md`.

| Componente | Versión | Dónde se fija | Estado |
|---|---|---|---|
| Ubuntu Server | 24.04 LTS | VM | curso |
| Docker Engine / Compose | script get.docker.com (curso) | anotar `docker version` y `docker compose version` aquí: ____ | pendiente |
| Chamilo | 1.11.40 (24/06/2026, estable) | `docker/.env` (`CHAMILO_VERSION`, `CHAMILO_URL`, `CHAMILO_SHA256`) | URL y SHA-256: ____ |
| PHP | 8.3 (`php:8.3-apache`) — plan B: 7.4 | `PHP_VERSION` en `.env` | resultado de la prueba de humo: ____ |
| MariaDB | `mariadb:11.8` — plan B: `mariadb:10.11` | `docker-compose.yml` | resultado de la prueba de humo: ____ |
| nginx (balanceador) | `nginx:1.30-alpine` | `docker-compose.yml` | curso |
| Apache / BIND9 / vsftpd (servidor) | paquetes de Ubuntu 24.04 | apt | anotar `apache2 -v`, `named -v`, `vsftpd -v`: ____ |

Nunca `latest`.
