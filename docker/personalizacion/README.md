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
