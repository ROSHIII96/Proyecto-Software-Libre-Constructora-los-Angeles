# Integrante 2 — Imagen de Chamilo, Compose, instalación y personalización

**Rama:** `int2-chamilo-imagen` · **Evidencias:** `docs/evidencias/int2/` · **Respuestas:** `docs/guias/respuestas-int2.md`

> **Usted desbloquea a 3, 4 y 5.** Suba la rama con `docker/` completo **a más tardar el lunes 26/10 por la noche**, aunque Chamilo todavía no esté instalado.

## Objetivo

Construir **una sola imagen reproducible** de Chamilo 1.11.40, levantar la pila (`bd` + `chamilo` + `balanceador`) con Docker Compose, instalar la plataforma **por el dominio HTTPS**, personalizarla con la marca de la constructora y dejar el contenido del curso. Es la misma estructura del Lab. #5 con la diferencia que muestra la tabla de la Sesión 13: **Chamilo no tiene imagen oficial**, así que el camino es un Dockerfile sobre `php:apache` más el código de la plataforma.

## Antes de empezar

- Docker funciona sin `sudo` y `docker compose version` responde (Sesión 12).
- Libere el 8081 del laboratorio anterior: `cd ~/lab5 && docker compose down` (sin `-v`).
- Necesita que el Integrante 1 tenga el VirtualHost HTTPS: **la instalación de Chamilo debe hacerse por `https://capacitacion.losangeles.internal/`**. Si todavía no está, haga primero los bloques 1 a 3 de la guía 1 (≈ 45 min): es más rápido que reinstalar.
- Mínimo 4 GB de RAM libres en la VM (Chamilo + MariaDB + 2 réplicas) y 10 GB de disco.

## Bloque 1 — Obtener el paquete oficial y fijar su huella (≈ 15 min)

**Qué va a hacer y por qué.** La imagen descarga el `.zip` oficial de Chamilo y **verifica su SHA-256**: así los cinco construyen exactamente el mismo software. (El paquete no pudo descargarse al preparar esta guía, por eso la URL y la huella las define usted.)

1. En el navegador abra la página de *Releases* del repositorio `chamilo/chamilo-lms`, etiqueta **v1.11.40**. Copie la **URL exacta** del paquete `.zip` de instalación (no el "Source code") y descárguelo.
2. Calcule su huella y prepare el `.env`.

```bash
sha256sum chamilo-1.11.40*.zip            # copie el valor (64 caracteres)
cd ~/proyecto-eif431o/docker
cp .env.example .env
chmod 600 .env
nano .env                                  # claves propias; CHAMILO_URL y CHAMILO_SHA256 reales
```

3. Anote URL, SHA-256 y fecha en `docs/versiones.md` y avise al grupo: **todos usan los mismos valores**.

> **Punto de control 1 (sí/no):** captura del `sha256sum` y de `docs/versiones.md` completado (sin mostrar claves). `.env` **no** aparece en `git status`.

**Pregunta de control:** ¿Por qué se verifica el SHA-256 del paquete y por qué `.env` no se sube a Git?

## Bloque 2 — Entender la imagen: tres archivos (≈ 20 min)

Lea `docker/chamilo/Dockerfile`, `chamilo.ini` y `chamilo-apache.conf`. Debe poder explicar cada línea (el profesor lo evalúa):

| Parte | Qué hace |
|---|---|
| `FROM php:${PHP_VERSION}-apache` | Imagen base: PHP con Apache. La versión viene del `.env` (8.3 por defecto; 7.4 es el plan B). |
| `docker-php-ext-install … gd intl zip pdo_mysql mysqli opcache soap` | Instala las extensiones que el instalador de Chamilo exige (`gd`, `intl`, `zip`, `pdo_mysql`…). `mbstring`, `curl`, `xml`, `fileinfo` ya vienen en la imagen. |
| `a2enmod rewrite headers` + `AllowOverride All` | Chamilo usa `.htaccess` con reescrituras (su guía lo exige). |
| `curl … && sha256sum -c` | Descarga el paquete y **falla el build** si la huella no coincide. |
| `cp -a … /var/www/html/` + `chown www-data` | Copia código **y `.htaccess`** y deja a Apache como dueño (el instalador necesita escribir `app/`, `web/` y `main/default_course_document/images/`). |
| `chamilo.ini` | Valores recomendados por Chamilo (`memory_limit`, `upload_max_filesize`…). `display_errors = Off` porque **el instalador lo exige**. `session.save_path=/sessions` → sesiones en un volumen compartido. |
| `SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on` | Detrás del proxy, Apache del contenedor sabe que el cliente usó HTTPS. |

Valide el compose sin ejecutarlo (como en el Lab. #5):

```bash
cd ~/proyecto-eif431o/docker
docker compose config -q && echo OK
```

*Qué debe ver:* `OK` (si falta algo del `.env`, el mensaje dice cuál variable).

> **Punto de control 2 (sí/no):** captura de `docker compose config -q` sin errores y de su explicación del Dockerfile en `respuestas-int2.md`.

**Pregunta de control:** ¿Qué copia el Dockerfile y **cuándo hay que reconstruir** la imagen? ¿Por qué `display_errors = Off`?

## Bloque 3 — Construir y levantar UNA réplica (≈ 25 min)

**Importante:** el primer arranque es con **una sola** réplica. Con dos, ambas intentan poblar a la vez el volumen `chamilo_app` vacío.

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d --build
docker compose ps
docker compose logs --tail 30 chamilo
docker images | grep chamilo-app
```

*Qué hace:* construye la imagen `chamilo-app:1.11.40-php8.3`, crea la red y los tres volúmenes, espera a que `bd` esté *healthy*, luego `chamilo`, y por último el balanceador. Es normal el aviso `pull access denied for chamilo-app` en el primer `up`: Compose intenta descargar la imagen antes de construirla (Sesión 13). La primera construcción tarda varios minutos.

*Qué debe ver:* `bd` y `chamilo` en `Up … (healthy)` y `balanceador` en `Up` con `127.0.0.1:8081->80/tcp`. `docker volume ls` lista `chamilo_datos_bd`, `chamilo_app` y `chamilo_sesiones`.

> **Punto de control 3 (sí/no):** captura de `docker compose ps` (tres servicios sanos), de `docker images | grep chamilo-app` y de `docker volume ls`.

**Pregunta de control:** ¿Por qué `chamilo` no se crea hasta que `bd` está *healthy* y qué parte del archivo lo logra? ¿Por qué ni `bd` ni `chamilo` publican puertos?

## Bloque 4 — Instalar Chamilo por el dominio HTTPS (≈ 30 min)

1. En Mint abra **`https://capacitacion.losangeles.internal/`** (siempre por el dominio, nunca por IP). Debe redirigir al instalador (`main/install/`).
2. **Pantalla de requisitos:** todo debe estar en verde. Capture la pantalla. Si PHP 8.3 marca algo en rojo, pase al Bloque 5 antes de continuar.
3. Datos de la base: servidor **`bd`** (el nombre del servicio, no `localhost`), puerto 3306, base **`chamilo`**, usuario **`chamilo_user`** y la clave de su `.env`. (El instalador borra y recrea la base; el usuario de la imagen ya tiene todos los privilegios **sobre esa base**, sin ser root.)
4. Cuenta de administrador con una clave que recuerde y **URL del portal: `https://capacitacion.losangeles.internal/`**.
5. Al terminar, endurezca la configuración (lo recomienda la guía de Chamilo) y confirme que el sitio carga completo con candado/advertencia de HTTPS:

```bash
docker compose exec chamilo chmod 0444 /var/www/html/app/config/configuration.php
docker compose exec chamilo grep -n "root_web" /var/www/html/app/config/configuration.php
```

*Qué debe ver:* `root_web` con `https://capacitacion.losangeles.internal/`. Si el panel de administración avisa de que existe `main/install`, bórrelo dentro del contenedor: `docker compose exec chamilo rm -rf /var/www/html/main/install`.

> **Punto de control 4 (sí/no):** (a) pantalla de requisitos en verde; (b) Chamilo cargando completo (estilos, menús) con la URL `https://capacitacion.losangeles.internal/` visible; (c) salida del `grep root_web`.

**Pregunta de control:** ¿Por qué se instala por el dominio HTTPS y no por la IP? ¿Dónde queda grabada esa URL y qué ocurre si es la equivocada? ¿Por qué el host de la base es `bd` y no `localhost`?

## Bloque 5 — Prueba de humo de compatibilidad (≈ 40 min, **con el Integrante 4**)

**Qué va a hacer y por qué.** Chamilo 1.11 es oficialmente PHP 7.4 y nadie probó MariaDB 11.8 con él. Antes de que los demás construyan sobre esta pila hay que **comprobar que lo que el proyecto necesita funciona**. Marque cada ítem; guarde captura de los que fallen.

| # | Prueba | ✔/✘ |
|---|---|---|
| 1 | Requisitos del instalador en verde | |
| 2 | Inicio de sesión como administrador | |
| 3 | Crear el curso "Seguridad en obra" | |
| 4 | Subir un PDF en *Documentos* y descargarlo | |
| 5 | Crear una *Lección* con 3 pasos y recorrerla como estudiante | |
| 6 | Crear un *Ejercicio* de 5 preguntas y resolverlo como estudiante | |
| 7 | Ver el progreso y la nota del estudiante como Instructor | |
| 8 | Los registros (`docker compose logs chamilo`) no muestran errores *fatal* ni *critical* | |
| 9 | Crear un usuario desde *Administración* | |

**Si algo falla**, en este orden, anotando el resultado en `docs/versiones.md`:

1. Lea el error y el log (`docker compose logs chamilo`, `docker compose logs bd`). Errores SQL del tipo *"Incorrect … value"* o *"doesn't have a default value"* apuntan al modo estricto de MariaDB: el Integrante 4 prueba `--sql-mode=NO_ENGINE_SUBSTITUTION` en el `command:` de `bd`.
2. Si el problema es de PHP: `PHP_VERSION=7.4` en `.env` y reconstruya. Cambiar de imagen **no** actualiza el volumen `chamilo_app` (conserva el código viejo), así que en esta etapa temprana se rehace todo: `docker compose down -v` ⚠ **borra la base y los archivos** (solo ahora, mientras no hay contenido; nunca más adelante) y se vuelve al Bloque 3.
3. Si el problema es de la base: `mariadb:10.11` en el compose, mismo procedimiento (el volumen de datos de 11.8 no se puede abrir con 10.11).

PHP 7.4 funciona pero **no tiene soporte de seguridad**: si hay que usarlo, se documenta como riesgo y como mitigación que el contenedor no está expuesto (solo `127.0.0.1`, detrás de Apache con HTTPS).

> **Punto de control 5 (sí/no):** la tabla completa y la decisión final (versiones fijadas) anunciada al grupo **a más tardar el martes 27/10**.

**Pregunta de control:** ¿Qué riesgo tiene PHP 7.4 y qué lo mitiga? ¿Por qué cambiar la versión de la imagen no actualiza el volumen `chamilo_app`?

## Bloque 6 — Personalización con la marca de la constructora (≈ 40 min)

**Requisito del PDF:** "no se acepta la apariencia por defecto sin editar". Logre: **logo propio y colores propios** (los de la constructora; invente una marca simple si no hay una), visibles en la página de inicio y dentro del curso. Es una tarea de investigación, como el Lab. #3: puede empezar por *Administración → Configuración de Chamilo* (apartados de apariencia/hojas de estilo) o por el tema dentro de `web/css/themes/`. Documente **qué camino usó y dónde queda guardado**.

Compruebe que lo personalizado **persiste** y lo ve cualquier réplica:

```bash
docker compose exec chamilo find /var/www/html -type f -mmin -60 \( -name "*.png" -o -name "*.jpg" -o -name "*.css" \)
```

> **Punto de control 6 (sí/no):** captura del antes y el después de la página de inicio, y de la ruta donde quedó el logo/tema.

**Pregunta de control:** ¿Dónde se guardó su logo? ¿Sobrevive a `docker compose down` y a recrear el contenedor? ¿Por qué?

## Bloque 7 — Persistencia: la plataforma sobrevive a `down` (≈ 15 min)

Igual que el Bloque 4 del Lab. #5, con Chamilo.

```bash
# 1) cree un usuario de prueba en Chamilo (Administración → Usuarios → Agregar)
docker compose down              # SIN -v
docker volume ls                 # los tres volúmenes siguen
docker compose up -d
```

*Qué debe ver:* tras la espera de `healthy`, el usuario de prueba sigue ahí y el logo también. **`docker compose down -v` borraría la plataforma**: solo en el Bloque 5, nunca después.

> **Punto de control 7 (sí/no):** captura del usuario antes y después de `down` + `up`, y de `docker volume ls` entre ambos.

**Pregunta de control:** ¿Qué diferencia hay entre `down` y `down -v`? ¿Qué guarda cada uno de los tres volúmenes?

## Bloque 8 — Contenido del curso (con el Integrante 3)

Siga la tabla de la **guía común, sección 7**. Su parte: el curso "Seguridad en obra", las **3 lecciones** (herramienta *Lecciones*), y el **PDF descargable** (herramienta *Documentos*). Redacte el contenido usted: nada de texto de relleno y con fuentes verificadas.

Al subir el PDF, averigüe **en qué carpeta lo guarda Chamilo** (es la pregunta que el Lab. #5 hace: "cada una documenta cuál es"):

```bash
docker compose exec chamilo find /var/www/html -name "*.pdf" -mmin -30
```

> **Punto de control 8 (sí/no):** capturas del curso con sus 3 lecciones, del PDF descargable (descargado por un estudiante) y del `find` con la ruta.

## Entregables en el repositorio (PR)

`docker/` completo y probado, `docs/versiones.md` con URL/SHA-256 y resultado de la prueba de humo, `docs/instalacion.md` con los pasos de los bloques 1 a 4 en sus palabras, evidencias y respuestas.

## Si algo falla

- **`failed to read dockerfile` / `no configuration file provided`:** ejecute `docker compose` desde `~/proyecto-eif431o/docker`.
- **`required variable CHAMILO_URL is missing`:** el `.env` no está en esa carpeta o le falta la variable.
- **El build falla en `sha256sum -c`:** la huella no corresponde al archivo de la URL; recalcule con el archivo descargado.
- **El build falla en `curl … 404`:** la URL no es la del `.zip` de instalación; cópiela de nuevo de la página de *Releases*.
- **`chamilo` queda `unhealthy`:** `docker compose logs chamilo`; casi siempre Apache no arrancó por un error de `chamilo-apache.conf` o un permiso.
- **Pantalla blanca o 500 tras instalar:** revise `docker compose logs chamilo` y los permisos de `app/` y `web/` (deben ser de `www-data`).
- **Estilos rotos o redirección a `http://`:** se instaló por otra URL; vea la guía 1 ("Si algo falla").
- **`port is already allocated` en el 8081:** el `~/lab5` sigue arriba (`docker compose down` allí) o use `sudo ss -tlnp | grep ':8081 '`.
