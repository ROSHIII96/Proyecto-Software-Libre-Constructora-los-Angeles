# Manual del Integrante 2: cómo quedó montado el servidor definitivo

Autor: Diego (Integrante 2). Servidor: `serverdiego`, el que se usa para la demo. Este manual cuenta lo que hice, en el orden en que lo hice, y cada comando es el que corrí de verdad. Si alguien tiene que montar todo de nuevo desde un servidor limpio, con esto debería poder hacerlo sin preguntarme.

Los valores sensibles (claves de la base, clave de administrador de Chamilo, claves de las cuentas FTP) **no están aquí ni en el repositorio**. Viven en `docker/.env` y se piden por pantalla.

## 0. Cómo está armado

```
Mint (cliente) ──DNS──> BIND9 (192.168.50.1, zona losangeles.internal)
Mint ──HTTPS──> Nginx del servidor (80 redirige a 443, certificado autofirmado)
                   └──> 127.0.0.1:8081  balanceador nginx (Docker)
                            ├──> chamilo-1 (php:8.3-apache)
                            └──> chamilo-2 (php:8.3-apache)
                                     └──> bd (mariadb:11.8), sin puertos publicados
```

Tres volúmenes con nombre fijo (así no cambian si cambia el nombre del proyecto):

| Volumen | Qué guarda |
|---|---|
| `chamilo_datos_bd` | la base de MariaDB: usuarios, cursos, notas |
| `chamilo_app` | código y configuración de Chamilo, cursos y archivos subidos, tema y logo |
| `chamilo_sesiones` | sesiones de PHP compartidas entre las réplicas |

Versiones exactas verificadas en el servidor: `docs/versiones.md`.

## 1. Preparar el servidor

1. Ubuntu Server con Docker Engine, Docker Compose, Git, Nginx, BIND9, vsftpd y OpenSSH Server (lista y versiones en `docs/versiones.md`).
2. Clonar el repositorio:

```bash
git clone https://github.com/ROSHIII96/Proyecto-Software-Libre-Constructora-los-Angeles.git ~/proyecto-eif431o
cd ~/proyecto-eif431o/docker
cp .env.example .env
nano .env          # poner las claves reales y los valores de Chamilo (abajo)
chmod 600 .env
```

3. En `.env` van, además de las claves, la versión y la huella del paquete de Chamilo:
   `CHAMILO_VERSION=1.11.40`, `PHP_VERSION=8.3`, `CHAMILO_URL` (el zip oficial de la versión v1.11.40 en GitHub) y `CHAMILO_SHA256` (el valor que está en `docs/versiones.md`). El Dockerfile compara el zip con esa huella y la construcción falla si no coincide. El `.env` nunca se sube a Git: está en `.gitignore`.

Hallazgo del servidor: había una MariaDB instalada con `apt` (de un laboratorio anterior) escuchando en `192.168.50.1:3306`. No tiene nada que ver con el proyecto y dejaba la base expuesta en la red, así que la detuve y la deshabilité (no borré sus datos):

```bash
sudo systemctl disable --now mariadb
```

## 2. DNS y HTTPS (parte de Integrante 1, así quedó en este servidor)

- La zona `losangeles.internal` está en `dns/db.losangeles.internal` (con `capacitacion`, `ftp`, `ns1` y `www`) y se declara con `dns/named.conf.local.ejemplo`. Se comprueba con `sudo named-checkzone losangeles.internal /etc/bind/db.losangeles.internal` y se recarga BIND.
- El certificado autofirmado está en `/etc/ssl/losangeles/` (`capacitacion.crt` y `capacitacion.key`).
- El Nginx del servidor usa `nginx/capacitacion.conf`: el puerto 80 redirige al 443, el 443 termina TLS y manda todo a `http://127.0.0.1:8081`. Le agregué `client_max_body_size 100m;` porque Chamilo deja subir archivos de hasta 100 MB (igual que PHP) y Nginx por defecto corta en 1 MB.

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Desde Mint: `getent hosts capacitacion.losangeles.internal` debe dar `192.168.50.1`, y `curl -sk -o /dev/null -w "%{http_code}\n" https://capacitacion.losangeles.internal/` debe dar `200`.

## 3. La imagen de Chamilo

La construyo una sola vez y las dos réplicas usan la misma. Son tres archivos en `docker/chamilo/`:

- **`Dockerfile`**: parte de `php:8.3-apache`, instala las extensiones que pide Chamilo (`gd`, `intl`, `zip`, `pdo_mysql`, `mysqli`, `opcache`, `soap`), activa `rewrite` y `headers`, descarga el zip oficial, **verifica el SHA-256**, lo copia a `/var/www/html`, crea `/sessions` y copia los dos archivos de abajo.
- **`chamilo.ini`**: ajustes de PHP (zona horaria de Costa Rica, 256 MB de memoria, 100 MB de subida, `display_errors = Off` porque el instalador lo exige, `session.save_path = "/sessions"` para compartir sesiones). Al final agregué `session.cookie_httponly = 1`: la cookie de sesión (`ch_sid`) ya no la puede leer JavaScript, lo que frena el robo de sesión por XSS.
- **`chamilo-apache.conf`**: `AllowOverride All` para los `.htaccess` de Chamilo, oculta la versión de Apache y le dice a PHP que el cliente usó HTTPS aunque el último tramo sea HTTP (`X-Forwarded-Proto`).

Hay que reconstruir con `docker compose build chamilo` cada vez que cambie cualquiera de esos archivos o la versión de Chamilo o de PHP, y después recrear los contenedores.

**Primer arranque con UNA sola réplica.** Con dos, las dos intentan llenar a la vez el volumen `chamilo_app` vacío y se pisan.

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d --build
docker compose ps
```

Es normal el aviso `pull access denied for chamilo-app` en el primer `up`: Compose busca la imagen antes de construirla. Deben quedar `bd` y `chamilo` en `healthy` y el balanceador en `127.0.0.1:8081->80/tcp`. Ni `bd` ni `chamilo` publican puertos.

## 4. Instalar Chamilo (por el dominio, no por la IP)

1. En Mint, abrir `https://capacitacion.losangeles.internal/`; redirige al instalador (`/main/install/`).
2. Requisitos en verde. Con PHP 8.3 aparecen avisos *deprecated*, que oculté con `error_reporting` en `chamilo.ini`; no hay errores fatales.
3. Datos de la base: servidor **`bd`** (el nombre del servicio, no `localhost`: `localhost` sería el propio contenedor de Chamilo, que no tiene base), puerto 3306, base `chamilo`, usuario `chamilo_user` y su clave del `.env`.
4. Cuenta de administrador y, ojo, la **URL del portal: `https://capacitacion.losangeles.internal/`**. El instalador me propuso una URL con `:80` y la tuve que cambiar. Esa URL queda grabada en `app/config/configuration.php` (`root_web`) y de ahí salen los enlaces, las redirecciones y los estilos; si queda mal, Chamilo redirige a una dirección que no existe.
5. Al terminar, la guía recomienda endurecer la configuración y comprobar la URL:

```bash
docker compose exec chamilo chmod 0444 /var/www/html/app/config/configuration.php
docker compose exec chamilo grep -n "root_web" /var/www/html/app/config/configuration.php
```

Si el panel avisa de que sigue existiendo `main/install`: `docker compose exec chamilo rm -rf /var/www/html/main/install`.

## 5. Dos réplicas y balanceador

Ya instalado, se suben las dos réplicas:

```bash
docker compose up -d --scale chamilo=2
docker compose ps
```

`docker/balanceador/nginx.conf` es lo que reparte. Lo importante:

- En vez de nombres fijos de contenedor, pregunta cada 5 s al DNS interno de Docker (`resolver 127.0.0.11 valid=5s`) quién está vivo. Una réplica detenida deja de recibir tráfico y una nueva entra sola, sin recargar nginx.
- `proxy_next_upstream ... tries 3`: si una réplica falla, reintenta con la otra. No reintenta POST, para no enviar dos veces un examen.
- Agrega la cabecera `X-Servidor` con la réplica que atendió, que sirve para la demostración.
- `/salud` responde `ok` y es el healthcheck del propio balanceador.

## 6. Prueba de humo (9 pruebas, 02/11/2026: 9/9)

Requisitos del instalador, login de administrador, crear el curso, subir y descargar un PDF, lección de 3 pasos, ejercicio de 5 preguntas, ver el progreso como profesor, logs sin errores fatales, crear un usuario. Resultados y explicación en `docs/guias/respuestas-int2.md`; capturas en `docs/evidencias/int2/capturas/`.

Para la prueba de logs: `docker compose logs chamilo | grep -iE "fatal|critical"` no devuelve nada.

## 7. Contenido y cuentas del curso

- Curso **Seguridad en obra**, código `SEGOBRA`.
- Lección con tres pasos: equipo de protección personal, trabajo en alturas y prevención de incendios y emergencias.
- `Documento-Ejemplo.pdf` en Documentos (queda en `app/courses/SEGOBRA/document/`).
- Ejercicio "Evaluación: Seguridad en obra": 5 preguntas, 7 puntos máximo.
- Cuentas: Carlos Ramírez (Profesor, usuario `Instructor1`) y tres estudiantes: Ana Mora (`estudiante1`), Luis Soto (`Estudiante2`) y María Vargas (`Estudiante3`). Las claves no están en el repositorio.

Lo creé desde Administración → Usuarios, y a los estudiantes los inscribí desde la herramienta Usuarios del propio curso.

## 8. Personalización (logo y colores)

El camino que usé es el panel de Chamilo (Administración → Configuración → Hojas de estilo), no tocar archivos a mano. Pasos completos en `docker/personalizacion/README.md`:

1. Pestaña "Nuevo archivo de hoja de estilo": nombre `losangeles`, subir `losangeles-tema.zip`.
2. Pestaña "Actualizar": elegir `Losangeles` y guardar.
3. Pestaña "Cambiar el logo": subir `logo-los-angeles.png` (Chamilo lo pide de 250x70 px en PNG y lo guarda a 245x68).

El tema es una copia del tema `chamilo` con los azules de `default.css` cambiados por el azul marino `#123456` y el naranja `#F28C18` del logo. Queda guardado en el volumen `chamilo_app` (`app/Resources/public/css/themes/losangeles/` y `web/css/themes/losangeles/`), por eso **sobrevive a `docker compose down` y a recrear contenedores** pero **no a `down -v`**. Por eso el logo y el zip del tema están también en el repositorio, y por eso entran en el respaldo de archivos (el simulacro de restauración recuperó el tema).

Dato útil: meter el tema en la imagen (Dockerfile) no sirve en este servidor, porque `chamilo_app` solo se llena con el contenido de la imagen cuando está vacío; en un servidor que ya tiene el volumen lleno, una imagen nueva no cambia nada.

## 9. Persistencia

- `docker compose down` borra contenedores y red; los volúmenes se quedan.
- `docker compose down -v` borra también los volúmenes, o sea todos los datos. **Nunca en el servidor definitivo.**
- Comprobación: hice `down` y `up -d` y el logo y el tema seguían ahí.

## 10. Pruebas de alta disponibilidad

`docker/probar-ha.sh` hace una petición por segundo y muestra la hora, el código HTTP y qué réplica respondió. Se corre en una terminal mientras en otra se detiene y se arranca una réplica:

```bash
cd ~/proyecto-eif431o/docker
./probar-ha.sh 60                      # terminal 1
docker stop chamilo-chamilo-1          # terminal 2
docker start chamilo-chamilo-1
```

Resultados (02/11/2026, logs crudos en `docs/evidencias/int2/`):

- **Cae una réplica:** el usuario no ve nada. Dos peticiones se reintentaron en la otra réplica y dieron 200; la más lenta tardó unos 3 s. La réplica volvió a recibir tráfico unos 7 s después de arrancar.
- **Caen las dos:** 502 y un 504 hasta que se levantan; primer 200 a los 3 s de arrancar. Con una réplica la caída no se nota; con las dos hay interrupción.
- La primera prueba se descartó por un hueco de 23 s del reloj de la VM (pausas de la máquina virtual, no fallos de Chamilo).

## 11. Base de datos: permisos y caídas

- `chamilo_user` tiene `GRANT ALL PRIVILEGES ON chamilo.*` y ve solo `chamilo` e `information_schema`. No es root.
- El contenedor `bd` no publica puertos (`docker compose port bd 3306` no devuelve nada) y el 3306 del servidor no escucha nada.
- Existe `root@%`: es el valor por defecto de la imagen y solo se alcanza desde la red interna de Docker. La salida de `SHOW GRANTS` incluye el hash de la clave, por eso no se sube sin taparlo.
- **`docker kill` de `bd`:** el contenedor quedó `Exited (137)` y no se reinició solo aunque la política es `unless-stopped`; se arrancó a mano, hizo `table crash recovery` y quedó listo en 4 s con los datos intactos. No pude verificar el motivo.
- **Caída real (`sudo kill -9` del proceso `mariadbd` desde el host):** reinicio automático (`RestartCount=1`), `healthy` a los 20 s, datos intactos (6 usuarios, 1 curso).

## 12. Respaldos, restauración y copia externa

### Respaldo

`backups/respaldar.sh` guarda en `~/respaldos` (fuera de Docker y de Git):

- `chamilo-bd-FECHA.sql.gz`: `mariadb-dump` ejecutado dentro del contenedor `bd` (con `--single-transaction`; la clave la toma del propio contenedor, no se escribe en el script).
- `chamilo-archivos-FECHA.tar.gz`: el volumen `chamilo_app` completo (configuración, cursos, archivos subidos, tema y logo).
- Escribe primero a `.tmp` y hace `mv` al terminar, así que nunca queda un archivo a medias con nombre definitivo, y borra los respaldos de más de 7 días.

La base tarda segundos y los archivos entre 10 y 40 minutos (352 MB; depende de qué tan cargada esté la VM).

### Cron en el servidor

```
30 2 * * * flock -n /tmp/respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1
```

`flock -n` evita que dos respaldos corran a la vez (por ejemplo, uno manual mientras llega la hora). **El cron solo corre si la VM está encendida a las 02:30**: el servidor estuvo apagado del 2 al 6 de noviembre y no hubo respaldos esas noches; hay que lanzar uno manual antes de la demo.

### Restauración

Los scripts `backups/restaurar.sh` y `backups/restaurar-archivos.sh` usan el volumen `chamilo_app` con nombre fijo: **ejecutados tal cual en el servidor definitivo reemplazan sus datos**. Por eso el simulacro lo hice en una copia aislada (proyecto `prueba`, volúmenes `prueba_*`, puerto 8082) y no en el servidor en uso. Detalle completo en `docs/evidencias/int2/restauracion-simulacro.md`; resumen: base restaurada en 83 s (6 usuarios, 1 curso, sin el usuario creado después del respaldo), archivos en 114 s, total unos 3,5 minutos, y se pierde todo lo hecho después del respaldo (límite de un respaldo diario).

### Copia externa en Mint (la jala Mint)

Mint no tiene servidor SSH: es Mint la que entra al servidor y trae los respaldos (solo necesita el cliente `ssh` y `rsync`).

1. En Mint, crear una clave solo para esto (sin frase de paso, porque cron no puede escribirla):

```bash
mkdir -p -m 700 ~/.ssh && ssh-keygen -t ed25519 -N "" -f ~/.ssh/respaldo_ed25519 -C "respaldo-mint"
cat ~/.ssh/respaldo_ed25519.pub
```

2. En el **servidor**, agregar esa línea pública a `~/.ssh/authorized_keys` (`chmod 600`).
3. Probar desde Mint la copia del respaldo de un día:

```bash
mkdir -p ~/respaldos-losangeles
rsync -avh --include='*2026-11-06*' --exclude='*' \
  -e "ssh -i ~/.ssh/respaldo_ed25519 -o StrictHostKeyChecking=accept-new" \
  diego@192.168.50.1:respaldos/ ~/respaldos-losangeles/
```

4. Dejarlo automático en Mint (su hora es UTC: `0 9` son las 03:00 de Costa Rica, después de que termina el respaldo de las 02:30):

```
0 9 * * * rsync -a --exclude="*.tmp" -e "ssh -i $HOME/.ssh/respaldo_ed25519" diego@192.168.50.1:respaldos/ $HOME/respaldos-losangeles/ >> $HOME/respaldos-losangeles/copia.log 2>&1
```

Y confirmar que `cron` esté activo en Mint: `systemctl is-active cron`.

Límites, dichos sin rodeos: solo funciona con Mint **y** el servidor encendidos a esa hora; protege contra perder la VM del servidor, no contra perder las dos; y la clave sin frase de paso permite abrir sesión en el servidor (mejora posible: limitarla con `command=` a solo `rsync`). El 06/11 Mint había perdido la clave, la carpeta y el crontab, y los rehicimos con estos pasos.

## 13. FTP (vsftpd)

- Configuración: `ftp/vsftpd.conf` del repo. La que traía el servidor de un laboratorio anterior quedó guardada en `/etc/vsftpd.conf.original`. Sin acceso anónimo, usuarios locales con escritura, **jaula en su carpeta** (`chroot_local_user=YES`) y puertos pasivos 40000-40100.
- Cuentas: `sudo bash ftp/crear-usuarios.sh` crea `derek`, `dixon`, `joseth` e `ivan` (la clave se pide con `passwd`, nunca en el script). `diego` es la cuenta real del administrador. Cada una con su `subida/` y su carpeta en `700`.
- Pruebas desde Mint con `curl`: listar la propia carpeta, subir un archivo a `subida/` y los intentos prohibidos (`ftp://.../home/dixon/` y `/etc/passwd`) dan `550 Failed to change directory.`
- Advertencia: FTP simple no cifra nada y la cuenta `diego` usaría la clave real del administrador en texto plano; las pruebas se hicieron con `derek`. En producción: FTPS o SFTP y cuentas `ftp_*` dedicadas.

## 14. Chequeo antes de la demo

En el servidor:

```bash
cd ~/proyecto-eif431o/docker && docker compose ps                    # 4 contenedores healthy
curl -skI --resolve capacitacion.losangeles.internal:443:127.0.0.1 https://capacitacion.losangeles.internal/ | head -1   # 200
systemctl is-active nginx named vsftpd docker                        # 4 x active
ls -lht ~/respaldos | head -5                                        # respaldo reciente
df -h / | tail -1                                                    # disco
```

En Mint (el cliente de la demo): `getent hosts capacitacion.losangeles.internal ftp.losangeles.internal` y el `curl` de HTTPS. Abrir la página unos minutos antes: la primera consulta de DNS del día falló una vez y la segunda ya funcionó.

Nota: el propio servidor no resuelve `capacitacion.losangeles.internal` (no usa su BIND como resolvedor); por eso en el servidor se prueba con `--resolve`. Es Mint la que debe resolverlo.

## 15. Problemas que nos pasaron

| Qué pasó | Por qué | Qué hicimos |
|---|---|---|
| El instalador proponía una URL con `:80` | no lo investigué | cambiar la URL del portal a `https://capacitacion.losangeles.internal/` |
| Había una MariaDB del sistema en `192.168.50.1:3306` | instalada en un laboratorio anterior | `systemctl disable --now mariadb` |
| `docker kill` no reinició la base | motivo no verificado | usar `kill -9` real del proceso para probar el reinicio automático |
| Pausas de 23 s y 3 min en la VM durante las pruebas de HA | la máquina virtual se detiene | descartar esos tramos; no suspender el equipo durante la demo |
| Los scripts de restauración pisan `chamilo_app` | nombre de volumen fijo | restaurar solo en una copia aislada |
| No hubo respaldos nocturnos del 3 al 6 de noviembre | el servidor estaba apagado a las 02:30 | respaldo manual el 06/11; encender el servidor por la noche si se quiere el automático |
| Mint perdió clave, carpeta y crontab | desconocido (parece un estado anterior de la VM) | rehacer los pasos del apartado 12 |
| Chamilo muestra "Media del ejercicio 0 %" en el resumen del profesor aunque Ana tiene 100 % | no lo investigué | en la demo se muestra el informe de Ejercicios, que sí coincide |

## 16. Límites aceptados

Puntos únicos de fallo: el Nginx del servidor, MariaDB (una sola instancia) y la VM del servidor. Las dos réplicas de Chamilo cubren la caída de una aplicación, no de lo demás. Respaldo diario: se puede perder hasta un día de cambios. FTP sin cifrar. Certificado autofirmado (el navegador avisa). Más contexto en `docs/decisiones.md`.

## 17. Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Compose, `.env.example`, Dockerfile, `chamilo.ini` | `docker/` |
| Logo y tema | `docker/personalizacion/` |
| Configuración de Nginx del servidor | `nginx/capacitacion.conf` |
| Scripts de respaldo, restauración y cron | `backups/` |
| FTP | `ftp/` |
| Pruebas con logs y capturas | `docs/evidencias/int2/` |
| Respuestas a las preguntas de control | `docs/guias/respuestas-int2.md` |
| Versiones y decisiones | `docs/versiones.md`, `docs/decisiones.md` |
