# Respuestas del Integrante 2 (Diego): imagen de Chamilo, instalación y servidor definitivo

## Bloque 1: SHA-256 y el `.env`

**¿Por qué se verifica el SHA-256 del paquete y por qué el `.env` no se sube a Git?**

El SHA-256 es como la huella del archivo `chamilo-1.11.40.zip`. Lo comparamos con la que dejamos registrada para estar seguros de que lo que bajamos es el paquete oficial, que no se corrompió en la descarga ni lo cambió alguien en el camino. Además así los cinco construimos exactamente la misma imagen. El Dockerfile hace esa comprobación al construir.

El `.env` tiene las contraseñas reales de la base de datos. Si se sube a Git se quedan guardadas en el historial, aunque después se borre el archivo. Por eso solo está el `.env.example` en el repositorio y cada servidor tiene su propio `.env`.

## Bloque 2: el Dockerfile

**¿Qué copia el Dockerfile y cuándo hay que reconstruir la imagen? ¿Por qué `display_errors = Off`?**

Partí de `php:8.3-apache`. El Dockerfile instala las extensiones de PHP que necesita Chamilo, descarga el paquete y le revisa el SHA-256, lo deja en la carpeta web, crea `/sessions` y copia dos archivos nuestros: `chamilo.ini` (los ajustes de PHP) y la configuración de Apache.

Hay que reconstruir con `docker compose build chamilo` cada vez que cambia algo de eso: el Dockerfile, `chamilo.ini`, la config de Apache o la versión de Chamilo o de PHP. Me pasó hoy: agregué `session.cookie_httponly = 1` a `chamilo.ini` y tuve que reconstruir y recrear el contenedor para que se aplicara.

`display_errors = Off` porque el instalador de Chamilo lo exige, y porque mostrarle errores a los usuarios regala rutas e información interna del servidor.

## Bloque 3: orden de arranque y puertos

**¿Por qué `chamilo` espera a que `bd` esté healthy? ¿Por qué ni `bd` ni `chamilo` publican puertos?**

`bd` tiene un `healthcheck` y `chamilo` lo usa con `depends_on` y `condition: service_healthy`. O sea que Docker no crea el contenedor de Chamilo hasta que MariaDB ya responde, y así no falla el arranque por una base que todavía se está levantando.

Ni `bd` ni `chamilo` publican puertos porque solo hace falta que se vean entre ellos por la red interna de Docker. La base la usa únicamente la aplicación, y a Chamilo se entra solo por el balanceador (127.0.0.1:8081) y el Nginx del servidor con HTTPS. Lo comprobé: `docker compose port bd 3306` no muestra ningún mapeo y el 3306 no está abierto en el host.

## Bloque 4: instalación por el dominio

**¿Por qué se instala por el dominio HTTPS y no por la IP? ¿Dónde queda guardada esa URL? ¿Por qué el host de la base es `bd`?**

Chamilo 1.11 guarda la URL base (`root_web`) en `app/config/configuration.php` cuando se instala, y de ahí saca los enlaces, las redirecciones y las rutas de los estilos. Si se instala con una URL equivocada, la plataforma redirige o intenta cargar cosas desde una dirección que no existe. A mí el instalador me propuso una URL con `:80` y la tuve que cambiar a `https://capacitacion.losangeles.internal/`.

El host de la base es `bd` porque ese es el nombre del servicio dentro de la red de Docker. Si pongo `localhost`, se refiere al propio contenedor de Chamilo, que no tiene MariaDB.

## Bloque 5: prueba de humo (servidor definitivo, 02/11/2026)

| # | Prueba | Resultado |
|---|---|---|
| 1 | Requisitos del instalador en verde | Pasó |
| 2 | Iniciar sesión como administrador | Pasó |
| 3 | Crear el curso "Seguridad en obra" | Pasó (código SEGOBRA) |
| 4 | Subir un PDF y descargarlo | Pasó (Documento-Ejemplo.pdf, 9,9 KB, se abre bien) |
| 5 | Lección de 3 pasos recorrida como estudiante | Pasó (barra al 100 %, también con la cuenta estudiante1) |
| 6 | Ejercicio de 5 preguntas resuelto como estudiante | Pasó (administrador 6/7, estudiante1 7/7) |
| 7 | Ver progreso y nota como profesor | Pasó (con la cuenta de Carlos: Ana Mora, usuario estudiante1, aparece con 100 %, aprobada, 1 intento; Luis y María, sin intentar) |
| 8 | Logs sin errores fatal ni critical | Pasó (el `grep` no devolvió nada) |
| 9 | Crear un usuario desde Administración | Pasó (Carlos Ramírez como Profesor y tres estudiantes) |

Las versiones quedaron fijadas en Chamilo 1.11.40, PHP 8.3 y MariaDB 11.8. No hizo falta el plan B (PHP 7.4 y MariaDB 10.11). Chamilo 1.11 es oficialmente para PHP 7.4, así que con 8.3 salen avisos de tipo *deprecated*. Los oculté con `error_reporting` en `chamilo.ini` y no hay ningún error fatal.

**¿Qué riesgo tiene PHP 7.4 y qué lo mitiga? ¿Por qué cambiar la versión de la imagen no actualiza el volumen `chamilo_app`?**

PHP 7.4 ya no recibe parches de seguridad. Si hubiera que usarlo, lo mitigaría que el contenedor no está expuesto (solo 127.0.0.1 detrás de Nginx con HTTPS) y dejarlo documentado como riesgo. Nosotros no lo usamos.

El volumen `chamilo_app` se llena con el código de la imagen solo la primera vez, cuando está vacío. Después Docker ya no lo vuelve a tocar, entonces una imagen nueva no actualiza el código que ya quedó en el volumen.

## Bloque 6: personalización

**¿Dónde se guardó el logo? ¿Sobrevive a `down` y a recrear el contenedor? ¿Por qué?**

Subí el logo (250×70 px, PNG) desde Administración, Configuración, Hojas de estilo, "Cambiar el logo". También creé un tema propio, `losangeles`, con el azul marino y el naranja del logo.

Todo eso quedó en el volumen `chamilo_app`, en `app/Resources/public/css/themes/losangeles/` y en `web/css/themes/losangeles/`. En el servidor es `/var/lib/docker/volumes/chamilo_app/_data/`.

Sí sobrevive a `docker compose down` y a recrear el contenedor, porque vive en un volumen con nombre y no dentro del contenedor. Lo comprobé haciendo un `down` y un `up -d`: el logo y el tema siguieron ahí. Además va incluido en el respaldo de archivos, y cuando restauré en la copia de prueba el tema apareció.

## Bloque 7: persistencia

**¿Qué diferencia hay entre `down` y `down -v`? ¿Qué guarda cada volumen?**

`down` borra los contenedores y la red pero deja los volúmenes. `down -v` borra también los volúmenes con nombre, o sea los datos.

- `chamilo_datos_bd`: la base de MariaDB (usuarios, cursos, notas).
- `chamilo_app`: el código y la configuración de Chamilo (incluido `configuration.php`), los cursos y archivos subidos, y el tema y el logo.
- `chamilo_sesiones`: las sesiones de PHP compartidas entre las réplicas, para que si una se cae la otra conserve la sesión.

Por eso el `down -v` solo lo usé en la copia de prueba, nunca en el servidor definitivo.

## Bloque 8: contenido del curso

- Curso SEGOBRA con la lección "Seguridad en obra" de 3 pasos (equipo de protección personal, trabajo en alturas y prevención de incendios y emergencias).
- Un PDF en Documentos: `app/courses/SEGOBRA/document/Documento-Ejemplo.pdf`.
- El ejercicio "Evaluación: Seguridad en obra", de 5 preguntas y 7 puntos como máximo.
- Cuentas: un Profesor (Carlos Ramírez) y tres estudiantes (Ana Mora, Luis Soto y María Vargas).
