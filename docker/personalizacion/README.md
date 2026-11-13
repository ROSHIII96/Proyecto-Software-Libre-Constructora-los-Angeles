# Personalización de Chamilo (marca de la constructora)

Contenido de esta carpeta:
- `logo-los-angeles.png`: el logo tal como lo dejó guardado Chamilo en el tema (245x68 px, PNG). Lo subí originalmente a 250x70 px y Chamilo lo ajustó al guardarlo.
- `losangeles-tema.zip`: tema `losangeles` (hoja `default.css` con el azul marino #123456 y el naranja #F28C18 del logo; trae el logo dentro de `images/`).

## Dónde queda guardado en el servidor
Todo vive en el volumen `chamilo_app`, no en la imagen ni en Git:
- `app/Resources/public/css/themes/losangeles/` y `web/css/themes/losangeles/`
- En el servidor: `/var/lib/docker/volumes/chamilo_app/_data/`
Sobrevive a `docker compose down` y a recrear los contenedores; se pierde con `down -v` (por eso este ZIP está en el repositorio) y va incluido en el respaldo de archivos.

## Cómo aplicarlo en un servidor nuevo (después de instalar Chamilo)
1. Administración, Configuración de Chamilo, categoría Hojas de estilo (en el navegador: `/main/admin/settings.php?category=Stylesheets`).
2. Pestaña "Nuevo archivo de hoja de estilo": nombre `losangeles`, subir `losangeles-tema.zip`.
3. Pestaña "Actualizar": elegir `Losangeles` y guardar.
4. Pestaña "Cambiar el logo": subir `logo-los-angeles.png` (Chamilo lo pide de 250x70 px en PNG y lo ajusta solo).

## Cómo se hizo el tema
Se descargó el tema `chamilo` desde la misma pantalla (botón Descargar), se copió a una carpeta `losangeles` y se cambiaron con `sed` los azules de `default.css` por los colores de la marca (barra de navegación, enlaces, menús abiertos y activos).


## Despliegue automatico en una VM nueva (`docker compose up -d --build`)
`chamilo/aprovisionar.sh` (entrypoint de la imagen) instala Chamilo sin navegador y deja todo listo. Archivos de esta carpeta que usa:
- `losangeles-tema.zip` y `logo-los-angeles.png`: tema y logo (se descomprime al arrancar).
- `chamilo-bd.sql.gz`: respaldo real de la base (usuarios, curso SEGOBRA, lecciones, evaluacion e intentos de los estudiantes). Si existe, se restaura; si no, se usa `sembrar.php` para crear datos de ejemplo.
- `curso-SEGOBRA.tar.gz` (opcional pero necesario para ver el PDF y las paginas de las lecciones): los archivos del curso, porque la base solo guarda sus nombres. Se genera en el servidor que ya tiene el curso:
  ```bash
  docker run --rm -v chamilo_app:/datos:ro -v "$PWD":/out nginx:1.30-alpine \
    tar czf /out/curso-SEGOBRA.tar.gz -C /datos/app/courses SEGOBRA
  ```
  y se copia a esta carpeta antes de hacer `git push`.
- `claves.php`: despues de restaurar, pone las claves del `.env` (`CHAMILO_ADMIN_PASS`, `CHAMILO_DEMO_PASS`) a `admin`, `Instructor1` y `estudiante1/2/3`.

El log del proceso queda en el contenedor: `app/aprovisionamiento.log`.
