# FTP en el servidor definitivo (Integrante 2)

Fecha: 2026-11-02. Se uso `ftp/vsftpd.conf` y `ftp/crear-usuarios.sh` de Derek tal cual.

## Instalacion
- `vsftpd` 3.0.5 ya estaba instalado (de un laboratorio previo). La configuracion que tenia el servidor se guardo en `/etc/vsftpd.conf.original` y se reemplazo por la del repositorio. Diferencia: la anterior traia `user_config_dir=/etc/vsftpd_user_conf` (del laboratorio); `local_umask`, `chroot_local_user` y `allow_writeable_chroot` ya tenian el mismo efecto.
- Servicio `active`, escuchando en el puerto 21.

## Cuentas
- `crear-usuarios.sh` creo `derek`, `dixon`, `joseth` e `ivan` (clave por `passwd` interactivo, fuera de scripts y de Git). `diego` ya existia: es el usuario real del servidor.
- Las cinco carpetas personales quedaron en `drwx------` (700) y cada una con su subcarpeta `subida/`.
- Advertencia: la cuenta FTP `diego` usa la clave real del administrador, que por FTP viaja en texto plano. Por eso las pruebas se hicieron con `derek`, no con `diego`. Para el equipo de produccion convendria usar cuentas `ftp_*` dedicadas.

## Pruebas desde la VM Mint (cliente, con curl)
1. Listar la carpeta de `derek`: ve solo su jaula (`/`), con `subida/`.
2. Subir un archivo a `subida/`: correcto.
3. Intentos prohibidos: `ftp://.../home/dixon/` y `ftp://.../etc/passwd` responden `550 Failed to change directory.`; la jaula (`chroot_local_user=YES`) impide salir de la carpeta propia.
- Nota: un primer intento del paso 3 termino por tiempo agotado (15 s) y no se uso como evidencia; repetido con salida detallada, la respuesta fue el 550 inmediato.

## Limites
- FTP simple no cifra el trafico (usuario, clave y archivos en texto plano). En produccion se usaria FTPS o SFTP; aqui se deja como mejora.
- Puertos pasivos 40000-40100 (definidos en la configuracion) deben estar abiertos si hubiera cortafuegos entre cliente y servidor.
