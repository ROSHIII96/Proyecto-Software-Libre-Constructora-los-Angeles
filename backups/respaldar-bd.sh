#!/bin/bash
# respaldar-bd.sh - respaldo rapido SOLO de la base 'chamilo' en ~/respaldos (ideal para pruebas)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
set -o pipefail

PROYECTO="${PROYECTO_DIR:-$HOME/proyecto-eif431o/docker}"
DESTINO="$HOME/respaldos"
FECHA=$(date +%F_%H%M)
BD_ARCHIVO="$DESTINO/chamilo-bd-$FECHA.sql.gz"
LOG="$DESTINO/respaldo.log"
DUMP='mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --routines --events "$MARIADB_DATABASE"'

mkdir -p "$DESTINO"
if ! cd "$PROYECTO"; then
  echo "$(date '+%F %T') ERROR: no existe $PROYECTO" >> "$LOG"; exit 1
fi

if docker compose exec -T bd sh -c "$DUMP" | gzip > "$BD_ARCHIVO.tmp" && [ -s "$BD_ARCHIVO.tmp" ]; then
  mv "$BD_ARCHIVO.tmp" "$BD_ARCHIVO"
  echo "$(date '+%F %T') OK BD (solo BD): $BD_ARCHIVO" >> "$LOG"
else
  rm -f "$BD_ARCHIVO.tmp"
  echo "$(date '+%F %T') ERROR: respaldo de la BD fallido" >> "$LOG"
  exit 1
fi
