#!/bin/bash
# crear-usuarios.sh - crea cuentas FTP para los integrantes del proyecto
# Uso: sudo ./crear-usuarios.sh
# Las claves NO se escriben aquí: passwd las pide de forma interactiva.

USUARIOS="diego derek dixon joseth ivan"

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecute con sudo"
  exit 1
fi

for u in $USUARIOS; do
  if ! id "$u" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$u"
    echo "Defina la clave de $u:"
    passwd "$u"
  else
    echo "El usuario $u ya existe."
  fi

  mkdir -p "/home/$u/subida"

  chown "$u:$u" "/home/$u" "/home/$u/subida"

  chmod 700 "/home/$u"
  chmod 755 "/home/$u/subida"

  echo "Usuario $u configurado correctamente."
done

echo
echo "Listo. Revise los usuarios con:"
echo "getent passwd diego derek dixon joseth ivan"

echo
echo "Revise los permisos con:"
echo "ls -ld /home/diego /home/derek /home/dixon /home/joseth /home/ivan"
