# Contenido nuevo del curso SEGOBRA (Chamilo)

Esta carpeta **solo agrega archivos nuevos**. No modifica nada de lo que ya existe en el proyecto (ni `docker/`, ni `docs/`, ni los scripts), así que se puede traer a cualquier rama sin riesgo de conflictos.

## Qué hay aquí

| Archivo | Qué es |
|---|---|
| `lecciones-seguridad-obra.html` | HTML de las 3 lecciones: equipo de protección, trabajo en alturas, protección contra incendios y emergencias. Cada una va separada por un comentario `LECCIÓN 1/2/3`. |
| `segundo-parcial-aiken.txt` | Segundo parcial: 15 preguntas de opción múltiple en formato Aiken, para importar en Ejercicios. |
| PDF nuevo | Se agrega en esta misma carpeta. |

## Cómo usarlo en su propio Chamilo

**Lecciones:** en el curso, Lecciones, crear una lección y un paso nuevo. En el editor, pulsar el botón **Código fuente** (`<>`) y pegar solo el bloque de la lección correspondiente. Volver a la vista normal para revisar que tablas y títulos se vean bien antes de guardar.

**Segundo parcial:** en el curso, Ejercicios, **Importar Aiken**, y subir `segundo-parcial-aiken.txt`. Después revisar el puntaje por pregunta (1 punto cada una, 15 en total).

**PDF:** en el curso, Documentos, subir el PDF.

## Cómo traerlo sin afectar su rama

Los archivos viven en la rama `int2-contenido-curso-segobra`. Para copiarlos a su rama de trabajo sin mezclar nada más:

```bash
git fetch origin
git checkout su-rama
git checkout origin/int2-contenido-curso-segobra -- contenido-curso/
```

Eso solo agrega la carpeta `contenido-curso/`. Si no quieren usar Git, también se pueden descargar los archivos desde la página de la rama en GitHub.

## Aviso

Esto es solo contenido del curso. **No incluye respaldos, claves ni el `.env`**. El Chamilo del servidor definitivo ya tiene este contenido cargado.
