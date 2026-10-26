# Integrante 4 — MariaDB, persistencia y seguridad de datos

**Rama:** `int4-mariadb` · **Evidencias:** `docs/evidencias/int4/` · **Respuestas:** `docs/guias/respuestas-int4.md`

## Objetivo

Que la base de datos de Chamilo sea **estable, persistente y accesible solo por la aplicación**, y poder demostrar que lo confirmado no se pierde. Es el mismo patrón del Lab. #5 y #6 del profesor (`mariadb:11.8`, volumen con nombre, healthcheck, sin `ports`, usuario propio), aplicado a Chamilo.

## Antes de empezar

- Su servicio ya está escrito en `docker/docker-compose.yml` (servicio `bd`). **Su trabajo es entenderlo, probarlo y defenderlo**, no reescribirlo.
- Con el Integrante 2 hace la *prueba de humo* (martes 27/10): decide si MariaDB 11.8 funciona con Chamilo 1.11.40 o se usa el plan B `mariadb:10.11`. **Su resultado se publica ese mismo día**, porque todo el equipo depende de él.
- Copie `docker/.env.example` a `docker/.env` y ponga contraseñas propias (largas, distintas entre sí). El `.env` **nunca** se sube a Git.

## Bloque 1 — Leer y explicar el servicio `bd` (≈ 30 min)

Abra `docker/docker-compose.yml` y prepare una explicación de cada elemento:

| Elemento | Para qué sirve |
|---|---|
| `image: mariadb:11.8` | Versión estable fijada (la misma del Lab. #5/#6); nunca `latest` |
| `command` con `utf8mb4` | Caracteres completos (tildes, ñ, emojis) en el curso |
| `environment` (`MARIADB_*`) | Crea la base y el usuario `chamilo_user` en el **primer** arranque |
| `volumes: chamilo_datos_bd:/var/lib/mysql` | Los datos viven fuera del contenedor |
| `healthcheck` | Docker marca `healthy` solo cuando MariaDB responde; Chamilo espera ese estado (`depends_on: service_healthy`) |
| sin `ports` | La base **no** es alcanzable desde la red; solo por el DNS interno (`bd`) |
| `restart: unless-stopped` | Se levanta sola si el proceso muere |

> **Punto de control 1 (sí/no):** `docs/guias/respuestas-int4.md` con la tabla anterior en sus palabras.

**Pregunta de control:** ¿Por qué cambiar `MARIADB_PASSWORD` en el `.env` *después* del primer arranque no cambia la contraseña real? *(Pista: la variable solo se usa cuando el volumen está vacío.)*

## Bloque 2 — Arranque y prueba de humo con el Integrante 2 (≈ 30 min)

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d bd
docker compose ps
docker compose logs bd | tail -20
```

*Qué debe ver:* `bd` en estado `healthy` y en el log `ready for connections`.

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT VERSION(); SHOW DATABASES;"'
```

*Qué debe ver:* la versión 11.8.x y la base `chamilo`. (La contraseña la toma de la variable del contenedor: no la escriba en el comando.)

Luego el Integrante 2 corre el instalador de Chamilo contra `bd`. **Si falla** por la base, pruebe en este orden y documente cada intento:

1. Revisar el error exacto en el instalador y en `docker compose logs bd`.
2. Agregar al `command` del servicio `--sql-mode=NO_ENGINE_SUBSTITUTION` (modo menos estricto), recrear con volumen vacío.
3. Plan B: `image: mariadb:10.11` (LTS), volumen vacío (`down -v` **solo ahora**, aún no hay datos).

> **Punto de control 2 (sí/no):** mensaje al grupo con el resultado ("11.8 funciona" o "usamos 10.11 por X") y captura de `SELECT VERSION()`. Quien cambie la versión actualiza `docs/versiones.md`.

**Pregunta de control:** ¿Por qué es mejor decidir la versión ahora y no con datos reales cargados?

## Bloque 3 — Permisos mínimos (≈ 30 min)

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW GRANTS FOR chamilo_user@\"%\"; SELECT user,host FROM mysql.user;"'
```

*Qué debe ver:* `chamilo_user` con privilegios **solo** sobre `chamilo`.* (no `*.*`). Si hubiera usuarios anónimos o `root` accesible desde `%` sin necesidad, anótelo y corríjalo.

Demuestre las **dos capas de acceso**:

```bash
# Capa 1: red. Desde el host NO debe haber puerto 3306 publicado
ss -tlnp | grep 3306            # sin resultados
docker compose port bd 3306     # sin mapeo
# Capa 2: permisos. El usuario de la app no puede tocar otras bases
docker compose exec bd sh -c 'mariadb -uchamilo_user -p"$MARIADB_PASSWORD" -e "SHOW DATABASES;"'
```

*Qué debe ver:* `chamilo_user` solo ve `chamilo` e `information_schema`.

> **Punto de control 3 (sí/no):** capturas de los tres comandos.

**Pregunta de control:** ¿Qué protege cada capa y qué pasaría si solo existiera una?

## Bloque 4 — Persistencia y durabilidad (≈ 40 min)

Con Chamilo instalado y al menos un usuario creado:

```bash
docker volume ls | grep chamilo_datos_bd
docker compose restart bd                    # reinicio ordenado: datos intactos
docker kill chamilo-bd-1                     # muerte abrupta; restart: unless-stopped lo levanta
docker compose ps
docker compose logs bd | tail -30            # busque "crash recovery" / "ready for connections"
```

Compruebe que el usuario sigue en Chamilo. Mida cuántos segundos tardó en volver a `healthy`.

Cuente filas antes y después (guarde ambos números):

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" chamilo -e "SELECT COUNT(*) FROM user; SELECT COUNT(*) FROM course;"'
```

Cuando el Integrante 2 haga su prueba `down` vs `down -v`, usted es testigo: `down` conserva el volumen; `down -v` lo destruye (por eso solo se permite en la etapa de humo).

> **Punto de control 4 (sí/no):** capturas de conteos antes/después del `docker kill`, log con la recuperación y tiempo medido.

**Pregunta de control:** ¿Por qué InnoDB no pierde las transacciones confirmadas aunque el proceso muera de golpe? ¿Y qué **sí** puede perderse? *(Lo no confirmado en ese instante.)*

## Bloque 5 — Monitoreo básico (≈ 20 min)

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW PROCESSLIST; SHOW STATUS LIKE \"Threads_connected\"; SHOW STATUS LIKE \"Uptime\";"'
docker system df -v | grep chamilo_datos_bd
docker compose logs --tail 50 bd
```

Con las dos réplicas de Chamilo activas, `Threads_connected` debe mostrar conexiones de ambas. Documente en `docs/monitoreo-bd.md` qué revisaría cada día (espacio del volumen, errores del log, conexiones).

> **Punto de control 5 (sí/no):** `docs/monitoreo-bd.md` y capturas con el `PROCESSLIST` en uso.

## Bloque 6 — Respaldo y restauración (con el Integrante 5) (≈ 40 min)

El Integrante 5 es dueño de los scripts (`backups/respaldar.sh`, `restaurar.sh`); usted es **quien valida que el respaldo realmente sirve**:

1. Cree un usuario de prueba, ejecute `backups/respaldar.sh`.
2. Cree otro usuario *después* del respaldo.
3. Restaure en una base limpia (`down -v` en una **copia de prueba**, no en producción) con `backups/restaurar.sh`.
4. Compare conteos: debe aparecer el primer usuario y **no** el segundo.

> **Punto de control 6 (sí/no):** capturas del antes/después y una frase sobre qué se pierde (lo ocurrido tras el último respaldo).

**Pregunta de control:** ¿Cuánto es el máximo de datos que se perdería con respaldo diario a las 02:30? ¿Qué lo reduciría?

## Etapa 3 opcional — replicación (solo si el profesor la exige)

**Fuera del temario y no probada por esta guía.** Si el profesor exige que otra VM tome el control con la base al día:

- *Réplica primario → secundario (replicación asíncrona de MariaDB):* simple de entender; la copia puede ir unos segundos atrasada, y el cambio de primario es **manual**.
- *Galera:* escritura en varios nodos, pero exige 3 nodos para quórum, cambia el comportamiento de algunas tablas y no se recomienda para el plazo.

No la empiece sin respuesta del profesor y sin los bloques 1–6 cerrados. Si se hace, documentarla como **experimental** y probar con datos de prueba.

## Entregables en el repositorio (PR)

`docs/guias/respuestas-int4.md`, `docs/monitoreo-bd.md`, la actualización de `docs/versiones.md` si cambió la versión, y evidencias.

## Si algo falla

- **`bd` queda `unhealthy`:** `docker compose logs bd`. Suele ser una contraseña mal escrita en el `.env` con el volumen ya inicializado → solo en etapa de humo: `down -v` y de nuevo.
- **Chamilo no conecta (`Access denied`):** el host debe ser `bd`, no `localhost`; usuario y contraseña del `.env`.
- **`Can't connect to MySQL server on 'bd'`:** `bd` no está `healthy` o los servicios no comparten red (mismo `docker-compose.yml`).
- **El instalador falla con modo SQL / motor:** ver Bloque 2.
- **Volumen lleno / disco:** `df -h` y `docker system df`; avise antes de que llegue al 90 %.
