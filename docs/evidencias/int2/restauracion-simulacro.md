# Simulacro de restauracion (Integrante 2, servidor definitivo)

Fecha: 2026-11-02. Se uso una copia aislada y desechable (proyecto `prueba`, volumenes `prueba_*`, puerto 8082) para no arriesgar el servidor definitivo; se borro al terminar.

## Respaldo
- `bash backups/respaldar.sh` termino con codigo 0. Base: `chamilo-bd-2026-11-02_1632.sql.gz` (51 KB, `gunzip -t` OK). Archivos: `chamilo-archivos-2026-11-02_1632.tar.gz` (352 MB, `tar tzf` lista el contenido).
- Duracion: la base, segundos; los archivos, casi 10 minutos (disco lento). Con 7 dias de retencion los archivos ocupan unos 2,5 GB.
- Estado al respaldar: 6 usuarios, 1 curso.

## Antes
- Despues del respaldo se creo el usuario `posterior1`: 7 usuarios, 1 curso (consulta SQL en el servidor definitivo).

## Desastre y restauracion (en la copia aislada, base vacia como un servidor nuevo)
- Base: `restaurar.sh` sobre `prueba-bd-1` recien creada. 83 s en total (unos 56 s del arranque de la base nueva y ~27 s del volcado). Resultado: **6 usuarios, 1 curso, 0 del usuario posterior**.
- Archivos: `restaurar-archivos.sh` (con el nombre del volumen cambiado a `prueba_app`): 114 s. Quedaron `app/config/configuration.php`, el tema `losangeles`, el PDF `app/courses/SEGOBRA/document/Documento-Ejemplo.pdf`, y la copia respondio con el titulo "Constructora Los Angeles - Capacitacion".
- Tiempo total de restauracion: unos 3,5 minutos (base + archivos).

## Lo que se perdio
- Todo lo hecho despues de las 16:32 (el usuario `posterior1`): es el limite de un respaldo diario.

## Limitaciones y notas
- No se abrio la copia con login en el navegador: Chamilo guarda su direccion `https://capacitacion.losangeles.internal` y redirige. Lo comprobado fue base, archivos y respuesta HTTP.
- Los scripts de Derek usan el volumen `chamilo_app` con nombre fijo: ejecutarlos tal cual en el servidor definitivo reemplaza sus datos. Por eso el simulacro se hizo en una copia con otro nombre de proyecto y de volumenes.
- El `docker-compose.yml` fija `name: chamilo_*` en los tres volumenes, de modo que cambiar solo el nombre del proyecto no basta para aislar una copia.
- El usuario `posterior1` se borro del servidor definitivo despues de la prueba (vuelve a haber 6 usuarios).
