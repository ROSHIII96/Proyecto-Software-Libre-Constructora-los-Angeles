#!/bin/bash
# restaurar-archivos.sh - restaura el volumen chamilo_app (configuracion, cursos, archivos subidos)
# Uso: ./restaurar-archivos.sh ~/respaldos/chamilo-archivos-AAAA-MM-DD_HHMM.tar.gz
# CUIDADO: reemplaza el contenido del volumen chamilo_app. Detenga las replicas antes.
set -o pipefail
PROYECTO="${PROYECTO_DIR:-$HOME/proyecto-eif431o/docker}"

if [ -z "$1" ] || [ ! -f "$1" ]; then
  echo "Uso: restaurar-archivos.sh ARCHIVO.tar.gz (debe existir)"; exit 1
fi
ARCHIVO=$(realpath "$1")
cd "$PROYECTO" || exit 1

docker compose stop chamilo balanceador
docker volume create chamilo_app >/dev/null
# borra el contenido actual y desempaqueta el respaldo (nginx:1.30-alpine ya esta descargada: trae tar)
if docker run --rm -i -v chamilo_app:/datos --entrypoint sh nginx:1.30-alpine \
     -c 'rm -rf /datos/* /datos/.[!.]* 2>/dev/null; tar xzf - -C /datos' < "$ARCHIVO"; then
  echo "Archivos restaurados: $ARCHIVO"
  docker compose up -d
else
  echo "ERROR: la restauracion de archivos fallo"; exit 1
fi
