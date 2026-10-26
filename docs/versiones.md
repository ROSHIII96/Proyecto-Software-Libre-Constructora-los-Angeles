# Versiones fijadas (todos usamos EXACTAMENTE estas)
Cambiar una versión requiere avisar a los cinco y anotarlo en `decisiones.md`.

| Componente | Versión | Dónde se fija | Estado |
|---|---|---|---|
| Ubuntu Server | 24.04 LTS en el curso; servidor del Integrante 2: 26.04 LTS | VM | cada integrante anota la suya |
| Docker Engine / Compose | Docker 29.9.2 / Compose v5.6.0 (servidor Int. 2) | `docker version`, `docker compose version` | anotado 25/10/2026 |
| Git | 2.53.0 (servidor Int. 2) | `git --version` | anotado 25/10/2026 |
| Chamilo | 1.11.40 (24/06/2026, estable) | `docker/.env` (`CHAMILO_VERSION`, `CHAMILO_URL`, `CHAMILO_SHA256`) | fijado, ver abajo |
| PHP | 8.3 (`php:8.3-apache`) — plan B: 7.4 | `PHP_VERSION` en `.env` | resultado de la prueba de humo: pendiente |
| MariaDB | `mariadb:11.8` — plan B: `mariadb:10.11` | `docker-compose.yml` | resultado de la prueba de humo: pendiente |
| nginx (balanceador) | `nginx:1.30-alpine` | `docker-compose.yml` | curso |
| Apache / BIND9 / vsftpd (servidor) | paquetes de Ubuntu del servidor de cada integrante | apt | anotar `apache2 -v`, `named -v`, `vsftpd -v`: pendiente |

Nunca `latest`.

## Valores de Chamilo (Integrante 2, 25/10/2026)
- CHAMILO_URL: https://github.com/chamilo/chamilo-lms/releases/download/v1.11.40/chamilo-1.11.40.zip
- CHAMILO_SHA256: 1cf4bf2cc7bae1ef1a1eff643235db1d552f78ddf4b6dd1e2d2dac9868679439
- Verificado con `sha256sum` tras descargar el ZIP (402 MB), coincide con el publicado en GitHub.
