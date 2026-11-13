#!/bin/bash
# Aprovisionamiento automatico de Chamilo (primer arranque en una VM nueva).
# Se ejecuta en SEGUNDO PLANO mientras Apache arranca. Es idempotente:
#   1) Si Chamilo no esta instalado, ejecuta el instalador web por HTTP (curl) con los datos del .env.
#   2) Instala el tema "losangeles" y el logo (siempre que falten).
#   3) Carga los datos de ejemplo (usuarios, curso, lecciones, evaluacion) una sola vez.
# Los registros quedan en /var/www/html/app/aprovisionamiento.log
set -u
WEB=/var/www/html
LOG=$WEB/app/aprovisionamiento.log
CONF=$WEB/app/config/configuration.php
MARCA=$WEB/app/.aprovisionado
BLOQUEO=$WEB/app/.aprovisionando.lock
URL_LOCAL=http://127.0.0.1
PORTAL="${CHAMILO_PORTAL_URL:-https://capacitacion.losangeles.internal/}"

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG" >&2; }

aprovisionar() {
  mkdir -p "$WEB/app"
  # Con varias replicas solo una aprovisiona (mkdir es atomico).
  mkdir "$BLOQUEO" 2>/dev/null || { log "otra replica esta aprovisionando; salgo"; return 0; }
  trap 'rmdir "$BLOQUEO" 2>/dev/null' RETURN

  [ -f "$MARCA" ] && { log "ya aprovisionado"; return 0; }

  log "esperando a Apache..."
  for i in $(seq 1 60); do curl -fs -o /dev/null "$URL_LOCAL/" && break; sleep 2; done

  # ---------- 1) Instalacion ----------
  if [ ! -s "$CONF" ] || ! grep -q "root_web" "$CONF"; then
    log "Chamilo sin instalar: ejecutando instalador desatendido"
    # El instalador usa valores por defecto salvo que la URL lleve ?running=1, y lee installType de la URL.
    # Por eso se manda UNA sola peticion directa al paso 6 (instalacion) con todos los campos.
    COOKIES=$(mktemp)
    curl -sS --max-time 900 -c "$COOKIES" -b "$COOKIES" -H "Accept-Language: es" \
      -o "$WEB/app/instalador-salida.html" \
      "$URL_LOCAL/main/install/index.php?running=1&installType=new&updateFromConfigFile=" \
      --data-urlencode "step6=Instalar" \
      --data-urlencode "dbHostForm=bd" \
      --data-urlencode "dbUsernameForm=${DB_USER}" \
      --data-urlencode "dbPassForm=${DB_PASS}" \
      --data-urlencode "dbNameForm=${DB_NAME}" \
      --data-urlencode "dbPrefixForm=" \
      --data-urlencode "singleDbForm=1" \
      --data-urlencode "urlForm=${PORTAL}" \
      --data-urlencode "urlAppendPath=" \
      --data-urlencode "pathForm=${WEB}/" \
      --data-urlencode "emailForm=${CHAMILO_ADMIN_EMAIL:-admin@losangeles.internal}" \
      --data-urlencode "languageForm=spanish" \
      --data-urlencode "adminLastName=Administrador" \
      --data-urlencode "adminFirstName=Chamilo" \
      --data-urlencode "adminPhoneForm=00000000" \
      --data-urlencode "loginForm=${CHAMILO_ADMIN_USER:-admin}" \
      --data-urlencode "passForm=${CHAMILO_ADMIN_PASS}" \
      --data-urlencode "campusForm=Constructora Los Angeles - Capacitacion" \
      --data-urlencode "institutionForm=Constructora Los Angeles" \
      --data-urlencode "institutionUrlForm=${PORTAL}" \
      --data-urlencode "encryptPassForm=bcrypt" \
      --data-urlencode "allowSelfReg=false" \
      --data-urlencode "allowSelfRegProf=false" || log "ERROR: fallo la peticion del instalador"
    rm -f "$COOKIES"
    if [ ! -s "$CONF" ]; then
      log "ERROR: el instalador desatendido no genero configuration.php (ver app/instalador-salida.html). Use el instalador web manualmente."
      return 1
    fi
    chmod 0444 "$CONF" || true
    rm -rf "$WEB/main/install"
    log "instalacion terminada"
  fi

  # ---------- 2) Tema y logo ----------
  if [ ! -d "$WEB/web/css/themes/losangeles" ]; then
    log "instalando tema losangeles"
    for destino in "$WEB/web/css/themes" "$WEB/app/Resources/public/css/themes"; do
      mkdir -p "$destino"
      unzip -qo /opt/personalizacion/losangeles-tema.zip -d "$destino"
    done
    chown -R www-data:www-data "$WEB/web/css/themes" "$WEB/app/Resources/public/css/themes"
  fi

  # ---------- 3) Datos de ejemplo ----------
  # Camino A (preferido): restaurar el respaldo real de la base (chamilo-bd.sql.gz), con usuarios, curso,
  #                       lecciones, evaluacion e intentos de los estudiantes.
  # Camino B (si no hay respaldo): crear los datos de ejemplo con sembrar.php.
  resultado=0
  if [ -f /opt/personalizacion/chamilo-bd.sql.gz ]; then
    log "restaurando respaldo de la base (chamilo-bd.sql.gz)"
    if gunzip -c /opt/personalizacion/chamilo-bd.sql.gz \
         | mariadb --skip-ssl -h bd -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" >> "$LOG" 2>&1; then
      log "base restaurada"
      if [ -f /opt/personalizacion/curso-SEGOBRA.tar.gz ]; then
        log "restaurando archivos del curso SEGOBRA"
        mkdir -p "$WEB/app/courses"
        tar xzf /opt/personalizacion/curso-SEGOBRA.tar.gz -C "$WEB/app/courses"
      else
        log "AVISO: no hay curso-SEGOBRA.tar.gz; el PDF y las paginas de las lecciones no tendran archivo (ver personalizacion/README.md)"
      fi
      php /opt/personalizacion/claves.php >> "$LOG" 2>&1 || resultado=1
    else
      log "ERROR restaurando la base"; resultado=1
    fi
  else
    log "cargando datos de ejemplo (sembrar.php)"
    php /opt/personalizacion/sembrar.php >> "$LOG" 2>&1; resultado=$?
  fi
  chown -R www-data:www-data "$WEB/app/courses" "$WEB/app/cache" 2>/dev/null || true
  if [ "$resultado" -eq 0 ]; then
    touch "$MARCA"
    log "aprovisionamiento completo"
  else
    log "ERROR en los datos de ejemplo (ver log); se reintentara al reiniciar el contenedor"
    return 1
  fi
}

( aprovisionar ) &

exec docker-php-entrypoint "$@"

