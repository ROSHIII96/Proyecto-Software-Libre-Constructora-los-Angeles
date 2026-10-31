#!/bin/bash
# restaurar.sh - restaura la BASE desde un respaldo .sql.gz  (servicio bd debe estar healthy)
# Uso: ./restaurar.sh ~/respaldos/chamilo-bd-AAAA-MM-DD_HHMM.sql.gz
set -o pipefail
PROYECTO="${PROYECTO_DIR:-$HOME/proyecto-eif431o/docker}"
CLIENTE='mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"'

if [ -z "$1" ] || [ ! -f "$1" ]; then
  echo "Uso: restaurar.sh ARCHIVO.sql.gz (debe existir)"; exit 1
fi
ARCHIVO=$(realpath "$1")
cd "$PROYECTO" || exit 1

if zcat "$ARCHIVO" | docker compose exec -T bd sh -c "$CLIENTE"; then
  echo "BD restaurada: $ARCHIVO"
else
  echo "ERROR: la restauracion de la BD fallo"; exit 1
fi
