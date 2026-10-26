#!/bin/bash
# probar-ha.sh - una peticion por segundo; muestra hora, codigo HTTP y que replica respondio
# Uso: ./probar-ha.sh [segundos]     (por defecto 60; Ctrl+C para terminar)
# Sirve de evidencia: lo que aparece aqui es lo que ve un usuario mientras se detiene/arranca una replica.
DOM="capacitacion.losangeles.internal"
DUR="${1:-60}"
for i in $(seq 1 "$DUR"); do
  R=$(curl -sk --max-time 5 --resolve "$DOM:443:127.0.0.1" -o /dev/null -D - "https://$DOM/" \
      | awk 'BEGIN{c="---"; s="(sin respuesta)"} /^HTTP/{c=$2} tolower($1)=="x-servidor:"{s=$2; gsub(/\r/,"",s)} END{print c, s}')
  echo "$(date +%T)  $R"
  sleep 1
done
