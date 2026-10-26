#!/bin/bash
# respaldar.sh - respaldo de la base 'chamilo' y de los archivos de la plataforma en ~/respaldos
# Basado en el Laboratorio #6 del curso. Uso: ~/proyecto-eif431o/backups/respaldar.sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin   # ruta fija para Cron
set -o pipefail

PROYECTO="${PROYECTO_DIR:-$HOME/proyecto-eif431o/docker}"   # carpeta del docker-compose.yml
DESTINO="$HOME/respaldos"                                   # FUERA de Docker y del repositorio
FECHA=$(date +%F_%H%M)
BD_ARCHIVO="$DESTINO/chamilo-bd-$FECHA.sql.gz"
FILES_ARCHIVO="$DESTINO/chamilo-archivos-$FECHA.tar.gz"
LOG="$DESTINO/respaldo.log"
# Clave y nombre de la base los conoce el contenedor: no se escriben en el script (comillas simples)
DUMP='mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --routines --events "$MARIADB_DATABASE"'

mkdir -p "$DESTINO"
if ! cd "$PROYECTO"; then
  echo "$(date '+%F %T') ERROR: no existe $PROYECTO" >> "$LOG"; exit 1
fi

# 1) Base de datos (tablas, usuarios de Chamilo, cursos, calificaciones...)
if docker compose exec -T bd sh -c "$DUMP" | gzip > "$BD_ARCHIVO.tmp" && [ -s "$BD_ARCHIVO.tmp" ]; then
  mv "$BD_ARCHIVO.tmp" "$BD_ARCHIVO"
  echo "$(date '+%F %T') OK BD: $BD_ARCHIVO" >> "$LOG"
else
  rm -f "$BD_ARCHIVO.tmp"
  echo "$(date '+%F %T') ERROR: respaldo de la BD fallido" >> "$LOG"
  exit 1
fi

# 2) Archivos de la plataforma (volumen chamilo_app: incluye app/config/configuration.php, cursos y uploads)
if docker run --rm -v chamilo_app:/datos:ro --entrypoint tar nginx:1.30-alpine czf - -C /datos . > "$FILES_ARCHIVO.tmp" \
   && [ -s "$FILES_ARCHIVO.tmp" ]; then
  mv "$FILES_ARCHIVO.tmp" "$FILES_ARCHIVO"
  echo "$(date '+%F %T') OK ARCHIVOS: $FILES_ARCHIVO" >> "$LOG"
else
  rm -f "$FILES_ARCHIVO.tmp"
  echo "$(date '+%F %T') ERROR: respaldo de archivos fallido" >> "$LOG"
  exit 1
fi

# 3) Retencion: borra respaldos con mas de 7 dias
find "$DESTINO" -name 'chamilo-*' -mtime +7 -delete
