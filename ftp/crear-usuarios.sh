#!/bin/bash
# crear-usuarios.sh - crea una cuenta FTP por integrante (ftp_int1..5) y una por rol (ftp_instructor)
# Uso: sudo ./crear-usuarios.sh
# Las claves NO se escriben aqui: passwd las pide de forma interactiva.
USUARIOS="ftp_int1 ftp_int2 ftp_int3 ftp_int4 ftp_int5 ftp_instructor"

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecute con sudo"; exit 1
fi

for u in $USUARIOS; do
  if ! id "$u" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$u"
    echo "Defina la clave de $u:"
    passwd "$u"
  fi
  mkdir -p "/home/$u/subida"
  chown "$u:$u" "/home/$u" "/home/$u/subida"
  chmod 700 "/home/$u"            # nadie mas entra al home de este usuario
  chmod 755 "/home/$u/subida"
done
echo "Listo. Revise permisos con: ls -ld /home/ftp_*"
