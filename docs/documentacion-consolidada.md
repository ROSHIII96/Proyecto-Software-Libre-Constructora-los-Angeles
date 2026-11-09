# Documentación consolidada — Capacitación Chamilo para Constructora Los Ángeles

**Curso:** EIF431O Administración de Servidores basados en Software Libre
**Equipo:** Kernel Panic (Dixon, Diego, Joseth, Ivan, Derek)
**Escenario:** Chamilo LMS para la capacitación de los trabajadores
**Servidor de la demo:** `serverdiego` (Ubuntu Server, `192.168.50.1`)
**Cliente de pruebas y copia externa:** Linux Mint (`192.168.50.101`)

Este documento reúne, en un solo recorrido, la arquitectura, las decisiones, la reproducción del servidor, las pruebas y los costos del proyecto. Cuando un documento anterior describe otro procedimiento, manda lo que quedó corriendo en el servidor definitivo entre el 2 y el 6 de noviembre de 2026. Ese modelo anterior queda resumido al final, para no perder la evidencia de octubre.

Las claves de la base, del administrador de Chamilo y de las cuentas FTP viven en `docker/.env` y se piden por pantalla. No están en este texto ni en el repositorio.

---

## 1. El problema y lo que quedó funcionando

La constructora capacita a sus trabajadores (seguridad en obra, por ejemplo) sin dejar registro: no se sabe quién hizo cada capacitación ni con qué resultado. La solución es una plataforma Chamilo donde un instructor publica el curso y los trabajadores lo completan, con resultados guardados y consultables.

Lo que quedó funcionando en el servidor definitivo:

- Chamilo 1.11.40 con el curso **Seguridad en obra** (`SEGOBRA`): lección de 3 pasos, un PDF y una evaluación de 5 preguntas (7 puntos máximo).
- Un instructor, Carlos Ramírez (`Instructor1`), y tres estudiantes de ejemplo: Ana Mora (`estudiante1`), Luis Soto (`Estudiante2`) y María Vargas (`Estudiante3`). El progreso y las notas se consultan en los informes.
- Acceso por nombre: `https://capacitacion.losangeles.internal`, con HTTPS y certificado autofirmado.
- Dos réplicas de la aplicación detrás de un balanceador, con una sola base de datos MariaDB.
- Respaldos diarios automáticos en el servidor, copia que obtiene Mint y restauración probada en una copia aislada.
- FTP con vsftpd y una cuenta aislada por integrante.

---

## 2. Arquitectura

```
Mint (cliente, 192.168.50.101)
   │  DNS
   ▼
BIND9 (192.168.50.1)  zona losangeles.internal
   │  HTTPS
   ▼
Nginx del servidor   80 → redirige a 443 · certificado autofirmado
   │  127.0.0.1:8081 (solo local)
   ▼
Balanceador nginx (Docker)
   ├──► chamilo-1  (php:8.3-apache)
   └──► chamilo-2  (php:8.3-apache)
              │
              ▼
        bd  (mariadb:11.8)   sin puertos publicados
              │
              ▼
Volúmenes: chamilo_datos_bd · chamilo_app · chamilo_sesiones


Respaldos
  servidor  ~/respaldos
       ▲
       │  rsync por SSH (Mint obtiene la copia; 03:00 Costa Rica)
       │
  Mint  ~/respaldos-losangeles


FTP
  vsftpd · puerto 21 · pasivo 40000-40100 · usuarios en jaula
```

El cliente abre `https://capacitacion.losangeles.internal`. BIND9 resuelve el nombre. Nginx del servidor termina TLS y envía el tráfico a `127.0.0.1:8081`. Ese puerto es el balanceador nginx de Docker, que reparte las solicitudes entre las dos réplicas de Chamilo. Chamilo usa MariaDB. Los datos viven en volúmenes con nombre fijo.

| Componente | Función | Versión / licencia |
|---|---|---|
| Chamilo LMS | Cursos, evaluaciones e informes | 1.11.40 · GPLv3+ |
| PHP + Apache | Ejecutan Chamilo dentro del contenedor | PHP 8.3 |
| MariaDB | Base de datos | 11.8 · GPLv2 |
| Nginx del servidor | Entrada HTTPS | BSD-2 cláusulas |
| Nginx en Docker | Balanceador entre réplicas | 1.30-alpine · BSD-2 cláusulas |
| BIND9 | DNS interno | MPL 2.0 |
| vsftpd | FTP | GPL |
| Docker Engine + Compose | Contenedores | Apache 2.0 |
| Linux (kernel) | Sistema operativo | GPLv2 |

### Persistencia

| Volumen | Qué guarda |
|---|---|
| `chamilo_datos_bd` | Base de MariaDB: usuarios, cursos, notas, configuración almacenada en la base |
| `chamilo_app` | Código y configuración de Chamilo (`configuration.php`), cursos, archivos subidos, tema y logo |
| `chamilo_sesiones` | Sesiones PHP compartidas, para que el usuario conserve la sesión si lo atiende la otra réplica |

Los nombres están fijados en `docker-compose.yml`. Cambiar solo el nombre del proyecto Compose no aísla una copia: hay que usar otros nombres de volumen.

- `docker compose down` borra contenedores y red. Los volúmenes se conservan. El logo y el tema siguieron presentes después de un `down` y un `up -d`.
- `docker compose down -v` borra también los volúmenes. En el servidor definitivo no se usa.

El volumen `chamilo_app` se llena con el código de la imagen solo la primera vez, cuando está vacío. Una imagen nueva no reemplaza el código que ya quedó en el volumen.

### Qué sale a la red

Hacia la red salen 80 y 443 (Nginx), 53 (DNS), 21 y 40000-40100 (FTP) y 22 (SSH). El balanceador escucha solo en `127.0.0.1:8081`. Chamilo no publica su puerto 80. MariaDB no publica el 3306: `docker compose port bd 3306` no devuelve mapeo. Durante la instalación el 8081 se publicó un tiempo hacia la red interna; al cerrar las pruebas volvió a `127.0.0.1:8081:80`.

### Puntos únicos de fallo

Las dos réplicas cubren la caída de una instancia de Chamilo. Siguen siendo únicos el Nginx del servidor, MariaDB y la máquina virtual principal. Perder la VM se recupera a mano con los respaldos que están en Mint.

---

## 3. Inventario de red

| Dato | Valor |
|---|---|
| Zona DNS | `losangeles.internal` |
| Sitio | `capacitacion.losangeles.internal` |
| Servidor | `192.168.50.1` (`serverdiego`, Ubuntu) |
| Cliente y destino de respaldos | `192.168.50.101` (Linux Mint) |
| Certificado | `/etc/ssl/losangeles/` (`capacitacion.crt`, `capacitacion.key`), autofirmado |
| Balanceador | `127.0.0.1:8081` |
| Chamilo | Puerto 80 interno, sin publicación |
| MariaDB | Puerto 3306 interno, sin publicación. Host desde Chamilo: `bd` |
| FTP | 21 y pasivo `40000-40100` |
| SSH | 22 en el servidor. Mint usa el cliente SSH para traer los respaldos |
| Proyecto Compose | `chamilo` |
| Respaldos locales | `~/respaldos` (fuera de Docker y de Git) |
| Respaldos en Mint | `~/respaldos-losangeles/` |
| Zona BIND | `dns/db.losangeles.internal` (`capacitacion`, `ftp`, `ns1`, `www`), declarada con `dns/named.conf.local.ejemplo` |
| Nginx del servidor | `nginx/capacitacion.conf` |

El propio servidor no usa su BIND como resolvedor. Las pruebas HTTPS hechas en el servidor llevan `--resolve`. Quien debe resolver el nombre es Mint.

Comprobaciones desde Mint:

```bash
getent hosts capacitacion.losangeles.internal
curl -sk -o /dev/null -w "%{http_code}\n" https://capacitacion.losangeles.internal/
```

La primera debe devolver `192.168.50.1` y la segunda `200`. La primera consulta DNS del día falló una vez; la segunda ya funcionó. Conviene abrir la página unos minutos antes de la demo.

---

## 4. Software libre

Todos los componentes principales tienen licencia aprobada por OSI. Fuentes usadas en el proyecto:

| Software | Licencia | Fuente |
|---|---|---|
| Chamilo LMS 1.11.40 | GPLv3+ | https://chamilo.org/en/download/ |
| MariaDB 11.8 | GPLv2 | https://mariadb.com/docs/general-resources/community/community/faq/licensing-questions/licensing-faq |
| Nginx | BSD de 2 cláusulas | https://nginx.org/ |
| BIND9 | MPL 2.0 | https://www.isc.org/bind/ |
| vsftpd | GPL | https://security.appspot.com/vsftpd.html |
| Docker Engine | Apache 2.0 | https://docs.docker.com/engine/install/ |
| Kernel Linux | GPLv2 | https://www.kernel.org/faq.html |

Eso permite usar, estudiar y adaptar las herramientas sin pagar licencia por usuario en estos componentes. El código se puede revisar, la empresa puede cambiar de servidor o de equipo técnico, y Chamilo se configura según la organización. La documentación y la comunidad de cada proyecto cubren actualizaciones y problemas conocidos.

### Chamilo frente a Moodle y a un LMS de suscripción

El enunciado asigna Chamilo. Aun así se comparó con Moodle (también libre) y con un LMS propietario de suscripción, descrito de forma genérica, sin cotización real.

| Criterio | Chamilo 1.11 | Moodle | LMS propietario (SaaS) |
|---|---|---|---|
| Licencia | GPLv3+ | GPLv3+ | Propietaria |
| Costo de licencia | ₡0 | ₡0 | Pago recurrente, normalmente por usuario |
| Cursos, lecciones, ejercicios e informes | Cubre este caso | Cubre este caso y bastante más | Cubre este caso |
| Instalación y operación | Una aplicación PHP y una base | Más módulos y ajustes | La opera el proveedor |
| Datos | En el servidor propio | En el servidor propio | En el proveedor |
| Dependencia del proveedor | Ninguna | Ninguna | Alta |
| Escalado | Réplicas y sesiones compartidas, ya probadas | Igual de posible | Lo resuelve el proveedor |
| Costo operativo | Horas técnicas, hardware y electricidad | Similar, o algo mayor por la complejidad | Incluido en la suscripción |

Para una constructora que necesita capacitación sencilla con registro de resultados, Chamilo cubre el requisito con menos operación que Moodle y sin el pago recurrente ni la dependencia de un servicio propietario. Moodle encaja si hicieran falta extensiones, analítica o volúmenes grandes. Moodle también permite cursos, usuarios, evaluaciones, progreso y personalización; la elección de este proyecto sigue la plataforma asignada al equipo.

### Otras elecciones

- **Nginx como entrada.** La configuración de proxy inverso y de balanceo es corta, y el mismo programa sirve de balanceador interno.
- **BIND9.** Un archivo `hosts` obliga a editar cada cliente. BIND9 resuelve el nombre para toda la red de pruebas.
- **MariaDB.** Es compatible con Chamilo y se distribuye bajo GPL, sin una edición comercial de por medio.
- **Docker Compose.** La misma imagen se reproduce en otro servidor y las réplicas se levantan con `--scale chamilo=2`.

---

## 5. Versiones

Las versiones importantes se escriben en `docker-compose.yml`, `.env` o el archivo que corresponda. No se usa la etiqueta `latest`. Si cambia una versión importante, el cambio se comunica al equipo y se anota en el registro de decisiones.

Paquete de Chamilo:

- Versión 1.11.40, fecha de la release 24/06/2026.
- Archivo `chamilo-1.11.40.zip`.
- URL: `https://github.com/chamilo/chamilo-lms/releases/download/v1.11.40/chamilo-1.11.40.zip`
- SHA-256: `1cf4bf2cc7bae1ef1a1eff643235db1d552f78ddf4b6dd1e2d2dac9868679439`

El Dockerfile compara el zip con esa huella. Si no coincide, la construcción falla. Así los cinco integrantes construyen la misma imagen y se detecta un paquete dañado o sustituido.

### Verificadas en el servidor definitivo (2026-11-02)

| Componente | Versión |
|---|---|
| Ubuntu Server | 26.04 LTS |
| Docker Engine | 29.9.2 |
| Docker Compose | 5.6.0 |
| Git | 2.53.0 |
| Chamilo LMS | 1.11.40 |
| PHP (dentro del contenedor) | 8.3.35 (NTS), compilado el 6 de octubre de 2026 |
| MariaDB (dentro del contenedor) | 11.8.9-MariaDB-ubu2404 |
| nginx del balanceador | 1.30.6 |
| Nginx del servidor | 1.28.3 (Ubuntu) |
| BIND9 | 9.20.24-1ubuntu0.4-Ubuntu |
| vsftpd | 3.0.5-0.4 |
| Tablas de la base `chamilo` | 239 |

rsync de la copia externa se comprueba en la VM Mint (`rsync --version`). Los paquetes de APT pueden variar un poco según la Ubuntu del servidor.

Chamilo 1.11 está documentado de forma oficial para PHP 7.4. Con PHP 8.3 aparecen avisos *deprecated*. Se ocultaron con `error_reporting` en `chamilo.ini`. No hubo errores fatales. El plan alternativo (PHP 7.4 y MariaDB 10.11) no hizo falta. PHP 7.4 ya no recibe parches de seguridad; si hubiera que usarlo, el contenedor seguiría detrás de Nginx y de `127.0.0.1`, y el riesgo quedaría escrito. En este servidor se usa PHP 8.3.

Comandos de comprobación: `docker version`, `docker compose version`, `git --version`, `nginx -v`, `named -v`, `vsftpd -v`, `rsync --version`, `lsb_release -a`.

---

## 6. Decisiones

| Fecha | Decisión | Alternativa | Motivo | Responsable |
|---|---|---|---|---|
| 25/10/2026 | Nginx del servidor como proxy HTTPS, un solo certificado | Apache del laboratorio | Un único punto de entrada HTTPS | Integrante 1 / equipo |
| 25/10/2026 | BIND9 para `capacitacion.losangeles.internal` | Archivo `hosts` en cada cliente | Resuelve el nombre para la red de pruebas | Integrante 1 |
| 25/10/2026 | nginx en Docker como balanceador | HAProxy | Ya formaba parte de la arquitectura | Integrante 3 |
| 25/10/2026 | Una sola MariaDB con volumen | Galera o replicación | Más simple de operar; los respaldos cubren la pérdida de datos. La replicación quedó como etapa opcional | Integrante 4 / equipo |
| 30/10/2026 | Respaldos en `~/respaldos`, fuera de Docker y de Git | Dentro de un volumen o contenedor | Sobreviven si se borran contenedores o volúmenes | Integrante 5 |
| 30/10/2026 | Respaldo diario a las 02:30 | Frecuencias más cortas | El curso cambia poco. La pérdida máxima ronda las 24 horas | Integrante 5 |
| 31/10/2026 | `flock` en el cron del respaldo | Cron directo | En la prueba cada minuto los respaldos se solaparon | Integrante 5 |
| 31/10/2026 | Copia externa en Mint | Solo copias locales | Si se pierde la VM, queda otra copia | Integrante 5 |
| 31/10/2026 | Copia externa automática con rsync y SSH, a las 03:00 | Copia manual | Sale después del respaldo de las 02:30 | Integrante 5 |
| 31/10/2026 | Clave SSH propia, sin frase de paso, solo para esa copia | Clave personal con frase | Cron no puede escribir una frase de paso | Integrante 5 |
| 31/10/2026 | FTP simple (vsftpd) para el curso | SFTP o FTPS | Lo pide la práctica. En producción se usaría un protocolo cifrado | Integrante 5 |
| 31/10/2026 | Balanceador solo en `127.0.0.1:8081` | `0.0.0.0:8081` | Nginx del servidor es la entrada | Equipo |
| 02/11/2026 | Chamilo 1.11.40, PHP 8.3 y MariaDB 11.8 | PHP 7.4 y MariaDB 10.11 | Prueba de humo 9 de 9 en el servidor definitivo | Integrante 2 |
| 02/11/2026 | Servidor definitivo: `serverdiego` (Integrante 2) | Repartir el sistema entre las máquinas de cada integrante | Lo evaluable lo sube cada integrante; lo práctico se centraliza | Equipo |
| 02/11/2026 | `client_max_body_size 100m` en el Nginx del servidor | El límite por defecto de 1 MB | Chamilo y PHP aceptan 100 MB; con 1 MB Nginx rechazaba el archivo antes de llegar a PHP | Integrante 2 |
| 02/11/2026 | `session.cookie_httponly = 1` en `chamilo.ini` | Cookie legible desde JavaScript | La cookie `ch_sid` sale con `HttpOnly` | Integrante 2 |
| 02/11/2026 | `systemctl disable --now mariadb` en el host | Dejar la MariaDB del sistema en `192.168.50.1:3306` | Era un resto de laboratorio, ajena a Chamilo, y dejaba el 3306 expuesto. Los datos de esa instalación no se borraron | Integrante 2 |
| 02/11/2026 | Restauración de prueba en una copia aislada (`prueba`, volúmenes `prueba_*`, puerto 8082) | `down -v` sobre el servidor definitivo | Los scripts usan el volumen `chamilo_app` con nombre fijo | Integrante 2 |
| 02/11/2026 | La copia externa la obtiene Mint (09:00 UTC = 03:00 Costa Rica) | Que el servidor empuje los archivos a Mint | Mint no necesita servidor SSH. No queda una clave del destino en el servidor. Un servidor perdido o comprometido no borra la copia. Solo ocurre si Mint está encendida a esa hora | Integrante 2 |

### Lo que costó cada decisión importante

| Decisión | Lo que se cede |
|---|---|
| Todo en Docker Compose | Hay que entender los volúmenes: un `down -v` borra los datos |
| Una sola MariaDB | La base es un punto único de fallo |
| Dos réplicas y balanceador nginx | Si caen las dos hay corte. El Nginx del servidor y la base siguen siendo únicos |
| El balanceador consulta el DNS de Docker cada 5 s | Depende del resolver interno de Docker (`127.0.0.11`) |
| Sesiones PHP en un volumen compartido | Un volumen más que cuidar y respaldar |
| `/salud` como healthcheck | Detecta una aplicación que responde, también cuando el contenido ya falló de otra forma |
| Certificado autofirmado | El dominio `.internal` no se valida con una CA pública. El navegador avisa. En producción se usaría una CA interna |
| Respaldos fuera de Docker | Hay que cuidarlos como cualquier carpeta del servidor |
| Mint obtiene la copia | Si Mint está apagada a las 03:00, esa noche no hay copia externa |
| `flock` | Una segunda ejecución sale al momento si ya hay un respaldo en curso |
| FTP simple | Usuario, clave y archivos viajan sin cifrar |
| Restaurar en copia aislada | La prueba es más larga de montar |

---

## 7. Cómo montar el servidor desde cero

Procedimiento del servidor definitivo. Requisitos en el servidor: Ubuntu Server con Docker Engine, Docker Compose, Git, Nginx, BIND9, vsftpd y OpenSSH Server.

### 7.1 Código y variables

```bash
git clone https://github.com/ROSHIII96/Proyecto-Software-Libre-Constructora-los-Angeles.git ~/proyecto-eif431o
cd ~/proyecto-eif431o/docker
cp .env.example .env
nano .env
chmod 600 .env
```

En `.env` van las claves y también `CHAMILO_VERSION=1.11.40`, `PHP_VERSION=8.3`, `CHAMILO_URL` (el zip oficial v1.11.40) y `CHAMILO_SHA256` (el valor de la sección 5). El `.env` está en `.gitignore`.

Si el host trae una MariaDB de un laboratorio anterior:

```bash
sudo systemctl disable --now mariadb
```

### 7.2 DNS

La zona está en `dns/`. Después de copiarla a `/etc/bind/`:

```bash
sudo named-checkconf
sudo named-checkzone losangeles.internal /etc/bind/db.losangeles.internal
sudo systemctl restart bind9
sudo systemctl status bind9
```

Desde Mint: `nslookup capacitacion.losangeles.internal` o `getent hosts capacitacion.losangeles.internal`.

### 7.3 HTTPS

El certificado autofirmado queda en `/etc/ssl/losangeles/`. El virtual host es `nginx/capacitacion.conf`: el puerto 80 redirige al 443, el 443 termina TLS y hace proxy a `http://127.0.0.1:8081`, con `client_max_body_size 100m`.

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 7.4 Imagen de Chamilo

Los tres archivos están en `docker/chamilo/`:

- **Dockerfile.** Parte de `php:8.3-apache`. Instala `gd`, `intl`, `zip`, `pdo_mysql`, `mysqli`, `opcache` y `soap`. Activa `rewrite` y `headers`. Descarga el zip oficial, verifica el SHA-256, lo copia a `/var/www/html`, crea `/sessions` y copia `chamilo.ini` y `chamilo-apache.conf`.
- **chamilo.ini.** Zona horaria de Costa Rica, 256 MB de memoria, subida de 100 MB, `display_errors = Off` (lo exige el instalador y evita mostrar rutas internas), `session.save_path = "/sessions"`, `session.cookie_httponly = 1` y `error_reporting` para ocultar los avisos *deprecated* de PHP 8.3.
- **chamilo-apache.conf.** `AllowOverride All` para los `.htaccess` de Chamilo, oculta la versión de Apache y le indica a PHP que el cliente usó HTTPS (`X-Forwarded-Proto`), aunque el último tramo sea HTTP.

Hay que reconstruir con `docker compose build chamilo` cuando cambie cualquiera de esos archivos o la versión de Chamilo o de PHP, y después recrear los contenedores.

El primer arranque usa **una sola réplica**. Con dos, ambas intentan llenar a la vez el volumen `chamilo_app` vacío.

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d --build
docker compose ps
```

El aviso `pull access denied for chamilo-app` en el primer `up` es esperable: Compose busca la imagen antes de construirla. Deben quedar `bd` y `chamilo` en `healthy` y el balanceador en `127.0.0.1:8081->80/tcp`.

`chamilo` declara `depends_on` con `condition: service_healthy` sobre `bd`. Docker espera a que MariaDB responda antes de crear Chamilo.

### 7.5 Instalar Chamilo por el dominio

1. En Mint, abrir `https://capacitacion.losangeles.internal/`. Redirige a `/main/install/`.
2. Los requisitos deben salir en verde.
3. Base de datos: host **`bd`** (el nombre del servicio en la red de Docker; `localhost` sería el propio contenedor de Chamilo), puerto 3306, base `chamilo`, usuario `chamilo_user` y la clave del `.env`.
4. Cuenta de administrador. La URL del portal debe quedar en `https://capacitacion.losangeles.internal/`. El instalador puede proponer una URL con `:80`; hay que cambiarla. Chamilo 1.11 guarda `root_web` en `app/config/configuration.php` y de ahí salen enlaces, redirecciones y estilos.
5. Al terminar:

```bash
docker compose exec chamilo chmod 0444 /var/www/html/app/config/configuration.php
docker compose exec chamilo grep -n "root_web" /var/www/html/app/config/configuration.php
```

Si el panel avisa de que sigue existiendo `main/install`:

```bash
docker compose exec chamilo rm -rf /var/www/html/main/install
```

Comprobar acceso al panel, inicio de sesión, conexión con MariaDB y que el instalador ya no esté.

Conteo de tablas (en las pruebas: 239):

```bash
cd ~/proyecto-eif431o/docker
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'
```

### 7.6 Dos réplicas

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d --scale chamilo=2
docker compose ps
```

`docker/balanceador/nginx.conf`:

- Consulta cada 5 segundos el DNS interno de Docker (`resolver 127.0.0.11 valid=5s`). Una réplica detenida deja de recibir tráfico y una nueva entra sin recargar nginx.
- `proxy_next_upstream` con 3 intentos. Si una réplica falla, reintenta en la otra. Los POST no se reintentan, para no enviar dos veces un examen.
- Agrega la cabecera `X-Servidor` con la réplica que atendió.
- `/salud` responde `ok` y es el healthcheck del balanceador.

### 7.7 Contenido, marca, FTP y respaldos

El curso, las cuentas y el tema se crean desde el panel (secciones 8 y 9). FTP, cron y copia externa están en las secciones 11 y 12.

### 7.8 Chequeo antes de la demo

En el servidor:

```bash
cd ~/proyecto-eif431o/docker && docker compose ps
curl -skI --resolve capacitacion.losangeles.internal:443:127.0.0.1 https://capacitacion.losangeles.internal/ | head -1
systemctl is-active nginx named vsftpd docker
ls -lht ~/respaldos | head -5
df -h / | tail -1
```

Se esperan cuatro contenedores en buen estado, HTTP 200, los cuatro servicios `active`, un respaldo reciente y disco con espacio. En Mint, `getent hosts` de `capacitacion.losangeles.internal` y de `ftp.losangeles.internal`, más el `curl` de HTTPS. Durante la demo no se suspende la máquina virtual: en las pruebas de alta disponibilidad el reloj de la VM saltó 23 segundos y 3 minutos, y esos tramos se descartaron.

---

## 8. MariaDB

El servicio `bd` en `docker/docker-compose.yml`:

| Elemento | Función |
|---|---|
| `image: mariadb:11.8` | Versión fija, sin `latest` |
| `command` con `utf8mb4` | Guarda tildes, eñe y demás caracteres del español |
| `environment` (`MARIADB_...`) | Crea la base y el usuario `chamilo_user` en el primer arranque |
| `volumes: chamilo_datos_bd:/var/lib/mysql` | Los datos sobreviven al contenedor |
| `healthcheck` | Docker marca `healthy` cuando MariaDB responde |
| Sin `ports` | Solo se alcanza por el DNS interno (`bd`) |
| `restart: unless-stopped` | Si el proceso muere, Docker lo vuelve a levantar |

`MARIADB_PASSWORD` del `.env` se aplica en el primer arranque, cuando el volumen está vacío. Cambiar el `.env` después no cambia la clave ya guardada en el volumen.

### Dos capas de acceso

1. **Red.** El 3306 no está publicado. `ss -tlnp | grep 3306` no debe mostrar el puerto del proyecto y `docker compose port bd 3306` no devuelve mapeo.
2. **Permisos.** `chamilo_user` tiene `GRANT ALL PRIVILEGES ON chamilo.*` y, al listar bases, ve `chamilo` e `information_schema`. No es root.

La imagen crea `root@%` por defecto. Solo se alcanza desde la red interna de Docker. `SHOW GRANTS` incluye el hash de la clave; esa salida no se publica sin taparla.

Comandos de comprobación, desde `~/proyecto-eif431o/docker`:

```bash
docker compose up -d bd
docker compose ps
docker compose logs bd | tail -20
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT VERSION(); SHOW DATABASES;"'
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW GRANTS FOR chamilo_user@\"%\"; SELECT user,host FROM mysql.user;"'
docker compose exec bd sh -c 'mariadb -uchamilo_user -p"$MARIADB_PASSWORD" -e "SHOW DATABASES;"'
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" chamilo -e "SELECT COUNT(*) FROM user; SELECT COUNT(*) FROM course;"'
```

Estado listo: contenedor `healthy` y, en el log, `ready for connections`.

### Caídas probadas el 02/11/2026

Antes de las pruebas había 6 usuarios y 1 curso.

- `docker kill` del contenedor `bd` lo dejó en `Exited (137)` y no se reinició solo, aunque la política es `unless-stopped`. Se arrancó a mano. El log mostró `Starting table crash recovery...` y `ready for connections` a los 4 segundos. Los 6 usuarios y el curso siguieron ahí. En esta versión de Docker, `docker kill` no sirve para demostrar el reinicio automático.
- `kill -9` del proceso `mariadbd` desde el host sí provocó el reinicio (`RestartCount=1`). Quedó `healthy` a los 20 segundos, con los mismos 6 usuarios y 1 curso.

Un reinicio ordenado (`docker compose restart bd`) también conserva los datos.

### Monitoreo

Plan de supervisión y comandos que ya se usaron sobre la base:

**Almacenamiento.** Disco y RAM del host (`df -h`) y espacio de los volúmenes (`docker system df -v | grep chamilo_datos_bd`, `docker volume ls | grep chamilo_datos_bd`). La saturación del disco degrada o detiene el servicio, y los respaldos de archivos ocupan cientos de megabytes por día.

**Eventos.** Logs de la plataforma y de los contenedores (`docker compose logs --tail 50 bd`, `docker compose logs chamilo`). Los registros viven en el servidor y las copias de respaldo salen también hacia Mint.

**Conexiones de la base.**

```bash
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW PROCESSLIST; SHOW STATUS LIKE \"Threads_connected\"; SHOW STATUS LIKE \"Uptime\";"'
```

**Red.** Revisar de forma periódica que sigan publicados solo los puertos previstos (80, 443, 53, 21, 40000-40100 y 22) y que 3306 y 8081 no estén abiertos hacia la red.

El proyecto deja documentado este plan. Las alertas automáticas (aviso cuando falla un respaldo o cuando el disco se llena) quedan como mejora.

---

## 9. Curso, cuentas, personalización y prueba de humo

### Contenido

- Curso **Seguridad en obra**, código `SEGOBRA`.
- Lección de tres pasos: equipo de protección personal, trabajo en alturas, y prevención de incendios y emergencias.
- `Documento-Ejemplo.pdf` (9,9 KB) en Documentos. En el volumen queda en `app/courses/SEGOBRA/document/`.
- Ejercicio **Evaluación: Seguridad en obra**: 5 preguntas, 7 puntos máximo.

Las cuentas se crearon en Administración → Usuarios. Los estudiantes se inscribieron desde la herramienta Usuarios del curso. Las claves no están en el repositorio.

### Personalización

Se hizo desde Administración → Configuración → Hojas de estilo (el detalle de archivos está en `docker/personalizacion/README.md`):

1. Pestaña de hoja de estilo nueva: nombre `losangeles`, archivo `losangeles-tema.zip`.
2. Pestaña Actualizar: elegir `Losangeles` y guardar.
3. Pestaña del logo: `logo-los-angeles.png`. Chamilo pide 250×70 px en PNG y lo guarda a 245×68.

El tema parte del tema `chamilo`. Los azules de `default.css` pasaron al azul marino `#123456` y al naranja `#F28C18` del logo. Queda en el volumen `chamilo_app` (`app/Resources/public/css/themes/losangeles/` y `web/css/themes/losangeles/`; en el host, bajo `/var/lib/docker/volumes/chamilo_app/_data/`). Sobrevive a `down` y a recrear contenedores. Entra en el respaldo de archivos: el simulacro recuperó el tema. Meter el tema en el Dockerfile no actualiza un volumen que ya está lleno.

### Prueba de humo (02/11/2026): 9 de 9

| # | Prueba | Resultado |
|---|---|---|
| 1 | Requisitos del instalador en verde | Pasó |
| 2 | Iniciar sesión como administrador | Pasó |
| 3 | Crear el curso Seguridad en obra | Pasó (`SEGOBRA`) |
| 4 | Subir un PDF y abrirlo | Pasó (`Documento-Ejemplo.pdf`, 9,9 KB) |
| 5 | Lección de 3 pasos como estudiante | Pasó (barra al 100 %, también con `estudiante1`) |
| 6 | Ejercicio de 5 preguntas | Pasó (administrador 6/7, `estudiante1` 7/7) |
| 7 | Progreso y nota como profesor | Pasó. Carlos ve a Ana Mora (`estudiante1`) con 100 %, aprobada, 1 intento. Luis y María sin intentar |
| 8 | Logs sin `fatal` ni `critical` | Pasó. `docker compose logs chamilo \| grep -iE "fatal\|critical"` no devolvió nada |
| 9 | Crear usuarios | Pasó (Carlos Ramírez como Profesor y tres estudiantes) |

El resumen del profesor muestra «Media del ejercicio 0 %» aunque Ana tiene 100 %. Esa pantalla no se investigó. En la demo se usa el informe de Ejercicios, que sí coincide con la nota.

### Capturas

Tomadas desde Mint contra `https://capacitacion.losangeles.internal/`. Las del 02/11 son la prueba de humo. Las 16 a 18, del 06/11, comprueban la cuenta del profesor. Están en `docs/evidencias/int2/capturas/`.

| # | Archivo | Qué muestra |
|---|---|---|
| 1 | `01-curso-creado.png` | Curso Seguridad en obra (`SEGOBRA`) |
| 2 | `02-pdf-subido-al-curso.png` | PDF de 9,9 KB en Documentos |
| 3 | `03-pdf-se-abre.png` | El PDF se abre en el navegador |
| 4 | `04-leccion-de-3-pasos.png` | Los tres pasos de la lección |
| 5 | `05-leccion-vista-estudiante.png` | Progreso al 100 % |
| 6 | `06-ejercicio-5-preguntas.png` | Ejercicio de 5 preguntas |
| 7 | `07-resultado-administrador-6-de-7.png` | Administrador: 6/7 |
| 8 | `08-usuarios-carlos-profesor.png` | Carlos Ramírez como Profesor |
| 9 | `09-estudiantes-inscritos.png` | Ana, Luis y María inscritos |
| 10 | `10-mis-cursos-estudiante.png` | Mis cursos, visto por un estudiante |
| 11 | `11-resultado-estudiante-7-de-7.png` | Ana (`estudiante1`): 7/7 |
| 12 | `12-puntuacion-de-los-alumnos.png` | Administrador 6/7 y Ana 7/7 |
| 13 | `13-logo-subido.png` | Logo en la cabecera |
| 14 | `14-tema-losangeles-guardado.png` | Hoja `Losangeles` guardada |
| 15 | `15-restauracion-copia-aislada.png` | Simulacro: base en 83 s, 6 usuarios y 1 curso |
| 16 | `16-carlos-con-logo-y-tema.png` | Sesión de Carlos con logo y tema |
| 17 | `17-carlos-informe-del-curso.png` | Informe del curso: 3 usuarios, Ana al 100 % en la lección |
| 18 | `18-carlos-informe-de-ejercicios.png` | Informe de ejercicios: Ana 100 % y 1 intento; Luis y María sin intentar |

---

## 10. Alta disponibilidad

`docker/probar-ha.sh` hace una petición por segundo y muestra la hora, el código HTTP y la réplica (la coma en la columna del servidor indica reintento). Se corre en una terminal mientras en otra se detiene y se arranca una réplica. Logs del 02/11/2026 en `docs/evidencias/int2/`.

```bash
cd ~/proyecto-eif431o/docker
./probar-ha.sh 60
docker stop chamilo-chamilo-1
docker start chamilo-chamilo-1
```

### Cae una réplica

Log: `ha-parada-una-replica.txt`. A las 16:10:47 se detuvo `chamilo-chamilo-1` (el `stop` tardó 1,5 s). Dos peticiones se reintentaron en la otra réplica y devolvieron 200; la más lenta tardó unos 3 segundos. A las 16:10:59 se volvió a arrancar y cerca de las 16:11:06 ya recibía tráfico otra vez (unos 7 segundos). El usuario no ve un error.

### Caen las dos

Log: `ha-parada-ambas-replicas.txt`. Tramo válido: 16:12:08 a 16:12:40.

| Hora | Qué pasó |
|---|---|
| 16:12:16 | `docker stop` de ambas. Respuesta 502 |
| 16:12:21 | 504 |
| 16:12:23–16:12:28 | 502 |
| 16:12:28 | `docker start` de ambas |
| 16:12:31 | Primer 200 (3 segundos después de arrancar) |

Con una réplica la caída no se nota. Con las dos hay interrupción hasta que arrancan. Después de las 16:12:40 el reloj de la VM salta unos 3 minutos; ese tramo se descarta. Una prueba anterior tuvo un hueco de 23 segundos por la misma causa y no se usa como evidencia.

### Cae la base

El detalle está en la sección 8. Una muerte real del proceso `mariadbd` se recupera sola en unos 20 segundos, con los datos confirmados intactos. La alta disponibilidad del proyecto cubre la aplicación Chamilo. El Nginx del servidor, MariaDB y la VM siguen siendo puntos únicos.

---

## 11. FTP

Configuración vigente en el servidor definitivo (02/11/2026): `ftp/vsftpd.conf` del repositorio. La configuración previa del laboratorio quedó en `/etc/vsftpd.conf.original`.

Opciones que deben quedar:

```
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_umask=077
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
```

Eso apaga el acceso anónimo, permite usuarios locales con escritura, encierra a cada uno en su carpeta y usa el modo pasivo en los puertos 40000 a 40100. Si hay un cortafuegos entre el cliente y el servidor, ese rango tiene que estar abierto.

```bash
sudo apt update
sudo apt install vsftpd -y
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.original
sudo cp ~/proyecto-eif431o/ftp/vsftpd.conf /etc/vsftpd.conf
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd
sudo systemctl status vsftpd
```

El estado esperado es `active (running)`, escuchando en el puerto 21. vsftpd en el servidor definitivo es 3.0.5.

Comprobar las directivas:

```bash
grep -E "anonymous_enable|local_enable|write_enable|chroot_local_user|allow_writeable_chroot|local_umask|pasv_enable|pasv_min_port|pasv_max_port" /etc/vsftpd.conf
```

### Cuentas del servidor definitivo

```bash
cd ~/proyecto-eif431o
sudo bash ftp/crear-usuarios.sh
```

El script crea `derek`, `dixon`, `joseth` e `ivan`. La clave se pide con `passwd` y no se escribe en el script ni en Git. `diego` ya existía: es la cuenta real del administrador del servidor. Cada carpeta personal quedó en modo `700` (`drwx------`) y cada una tiene `subida/`.

La cuenta `diego` usaría por FTP la clave real del administrador, en texto plano. Las pruebas se hicieron con `derek`. En un equipo de producción convienen cuentas dedicadas y FTPS o SFTP.

### Pruebas desde Mint (02/11/2026, con curl)

1. `derek` lista solo su jaula (`/`), con `subida/`.
2. La subida a `subida/` funciona.
3. `ftp://.../home/dixon/` y `ftp://.../etc/passwd` responden `550 Failed to change directory.` La jaula impide salir de la carpeta propia.

Un primer intento del paso 3 se agotó por tiempo (15 s) y no se usó como evidencia. Repetido con salida detallada, el 550 fue inmediato.

Desde el cliente `ftp` de Mint el recorrido equivalente es: `ftp 192.168.50.1`, entrar, `pwd`, `ls`, `cd subida`, `put` y `get`. Para salir, `bye`. Un archivo de prueba se puede crear antes con:

```bash
echo "Prueba FTP Constructora Los Angeles" > prueba-ftp.txt
```

FTP simple envía usuario, contraseña y archivos sin cifrar. Quien capture el tráfico puede leerlos. En producción se usaría SFTP o FTPS. Aquí se deja como límite aceptado del curso.

---

## 12. Respaldos y recuperación

Responsable del diseño de respaldos: Integrante 5, con apoyo del Integrante 4 en MariaDB. En el servidor definitivo el Integrante 2 dejó cron, copia externa y el simulacro aislado.

### Qué se guarda y dónde

`~/respaldos`, fuera de Docker y de Git. Borrar o recrear contenedores no borra esa carpeta.

`backups/respaldar.sh` genera, con fecha y hora:

- `chamilo-bd-FECHA.sql.gz`: `mariadb-dump` dentro del contenedor `bd`, con `--single-transaction`. La clave la toma el contenedor; el script no la guarda.
- `chamilo-archivos-FECHA.tar.gz`: el volumen `chamilo_app` completo (configuración, cursos, archivos, tema y logo).

Escribe primero un `.tmp` y lo renombra al terminar, así un corte no deja un archivo definitivo a medias. Anota el resultado en `~/respaldos/respaldo.log` y borra lo que tenga más de 7 días.

La base hace falta porque ahí están usuarios, cursos, inscripciones, notas y configuración. El volumen hace falta porque la base no contiene los PDF, el tema, el logo ni `configuration.php`. Con solo uno de los dos, Chamilo queda incompleto.

La base tarda segundos (unos 44 a 51 KB según la fecha). Los archivos pesan unos 350 MB y tardan entre 10 y 40 minutos, según la carga de la VM. Con 7 días de retención, los archivos rondan 2,5 GB.

```bash
cd ~/proyecto-eif431o
chmod +x backups/respaldar.sh
bash -n backups/respaldar.sh && echo "Sintaxis del script OK"
./backups/respaldar.sh
ls -lh ~/respaldos
tail -n 20 ~/respaldos/respaldo.log
df -h
```

Integridad:

```bash
gzip -t ~/respaldos/chamilo-bd-ARCHIVO.sql.gz && echo "BD OK"
tar -tzf ~/respaldos/chamilo-archivos-ARCHIVO.tar.gz > /dev/null && echo "ARCHIVOS OK"
```

Un volcado se puede mirar con `zcat ~/respaldos/chamilo-bd-ARCHIVO.sql.gz | head -n 30` para confirmar que es un dump de la base `chamilo`. `gzip -t` y `tar -tzf` comprueban el archivo comprimido. Una restauración real es la prueba que demuestra que la copia sirve.

### Cron del servidor

```
30 2 * * * /usr/bin/flock -n /tmp/respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1
```

`flock -n` evita que dos respaldos corran a la vez (uno manual y el de las 02:30, por ejemplo). Se eligió un respaldo diario porque el curso cambia poco. En el peor caso se pierden hasta unas 24 horas (inscripciones o notas de ese día). En una capacitación masiva convendría acortar el intervalo.

El cron solo corre si la VM está encendida a las 02:30. El servidor estuvo apagado del 2 al 6 de noviembre y no hubo respaldos nocturnos. El 6 de noviembre, a las 13:09, se lanzó uno manual que terminó a las 13:50 (41 minutos, con la VM cargada; lo habitual son unos 10).

La línea anterior del laboratorio (`~/scripts/respaldar.sh`, que respaldaba la MariaDB del host) quedó comentada. El 02/11 se programó una ejecución única a las 17:00: cron la lanzó (`OK BD` a las 17:00:07) y después se quitó esa línea de prueba.

Antes de dejar el cron diario se probó un respaldo cada minuto. El de archivos dura más de un minuto, así que se encimaron procesos y creció el uso de disco. Para verlos: `pgrep -af respaldar.sh`. Para cortarlos: `pkill -f respaldar.sh`. Los temporales se localizan con `find ~/respaldos -type f -name "*.tmp" -ls` y se borran con `rm -f ~/respaldos/*.tmp`. `command -v flock` devuelve `/usr/bin/flock`.

`mariadb-dump` desde cron usa `docker compose exec -T`: cron no tiene terminal, y `-T` evita que Docker intente asignar una.

### Copia externa: Mint la obtiene

Mint entra al servidor y trae los respaldos. Hacen falta el cliente `ssh` y `rsync` en Mint. No hace falta un servidor SSH en Mint ni una clave privada en el servidor. Si el servidor se pierde o se compromete, no puede borrar la copia que ya está en Mint.

1. En Mint, clave solo para esto, sin frase de paso (cron no puede escribirla). No va a Git.

```bash
mkdir -p -m 700 ~/.ssh
ssh-keygen -t ed25519 -N "" -f ~/.ssh/respaldo_ed25519 -C "respaldo-mint"
cat ~/.ssh/respaldo_ed25519.pub
```

2. En el servidor, agregar esa línea pública a `~/.ssh/authorized_keys` (`chmod 600`).
3. Probar desde Mint:

```bash
mkdir -p ~/respaldos-losangeles
rsync -avh --exclude="*.tmp" \
  -e "ssh -i ~/.ssh/respaldo_ed25519 -o StrictHostKeyChecking=accept-new" \
  diego@192.168.50.1:respaldos/ ~/respaldos-losangeles/
```

La prueba manual trajo la base y los 352 MB de archivos a unos 5 MB/s. Se excluyen los `.tmp` a medio escribir. El 06/11, tras rehacer la clave, una copia de prueba del día (368 MB) tardó 28 segundos.

4. Cron en Mint. Su reloj está en UTC: `0 9` son las 03:00 de Costa Rica, después del respaldo de las 02:30.

```
0 9 * * * rsync -a --exclude="*.tmp" -e "ssh -i $HOME/.ssh/respaldo_ed25519" diego@192.168.50.1:respaldos/ $HOME/respaldos-losangeles/ >> $HOME/respaldos-losangeles/copia.log 2>&1
```

Comprobar `systemctl is-active cron` en Mint y `crontab -l` en ambos equipos.

Límites: las dos máquinas tienen que estar encendidas a esa hora; si Mint está apagada, la copia se hace a mano. Cubre la pérdida de la VM del servidor. Si se pierden Mint y el servidor a la vez, no hay tercera copia. La clave sin frase permite abrir sesión en el servidor; una mejora es limitarla con `command=` a solo `rsync`.

El 06/11 Mint había perdido la clave, la carpeta y el crontab. Se rehicieron con estos pasos.

### Restauración

Scripts:

- `backups/restaurar.sh`: importa un `.sql.gz` (usuarios, cursos, inscripciones, calificaciones y lo demás que esté en MariaDB).
- `backups/restaurar-archivos.sh`: recupera el `.tar.gz` en el volumen de la aplicación. Detiene los servicios que corresponde, restaura y los vuelve a levantar. Durante ese tramo la plataforma no atiende.

Hay que usar un par de base y de archivos del mismo momento. La restauración reemplaza la información actual. `docker compose down -v` no se ejecuta en el servidor definitivo: los scripts apuntan al volumen `chamilo_app` por su nombre fijo y pisarían la instalación en uso.

Orden, en un entorno de pruebas:

1. `gzip -t` y `tar -tzf` sobre los dos archivos.
2. `docker compose up -d bd` y esperar `healthy`. No importar mientras MariaDB aún arranca.
3. `./backups/restaurar.sh ~/respaldos/NOMBRE.sql.gz`. Mensaje esperado: `BD restaurada: ...`.
4. Contar tablas.
5. `./backups/restaurar-archivos.sh ~/respaldos/NOMBRE.tar.gz`.
6. `docker compose up -d` y `docker compose ps`. `bd` y `chamilo` en `healthy`, balanceador en marcha.
7. `curl -I http://127.0.0.1:8081` debe dar `HTTP/1.1 200 OK`.
8. En el navegador: inicio de sesión, usuarios, cursos y documentos. El 200 solo no garantiza que los datos estén completos.

Problemas frecuentes:

| Síntoma | Qué hacer |
|---|---|
| MariaDB no está disponible | `docker compose ps` y esperar `healthy` en `bd` |
| El archivo no existe | `ls -lh ~/respaldos/` y usar el nombre real |
| El respaldo está dañado | `gzip -t` o `tar -tzf` y elegir otra copia, incluida la de Mint |
| Chamilo responde y faltan documentos | Restaurar también el `.tar.gz` del mismo momento |
| La base responde y Chamilo no arranca | `docker compose ps` y `docker compose logs --tail=50 chamilo` |

Si se pierde el servidor, los archivos de `~/respaldos-losangeles/` en Mint se copian a un servidor reconstruido y se siguen estos pasos.

### Simulacro del 02/11/2026 (copia aislada)

Se usó un proyecto desechable `prueba`, volúmenes `prueba_*` y puerto 8082. Se borró al terminar.

- `bash backups/respaldar.sh` terminó con código 0. Base: `chamilo-bd-2026-11-02_1632.sql.gz` (51 KB, `gunzip -t` correcto). Archivos: `chamilo-archivos-2026-11-02_1632.tar.gz` (352 MB). Estado al respaldar: 6 usuarios y 1 curso. Los archivos tardaron casi 10 minutos.
- Después del respaldo se creó `posterior1` en el servidor definitivo: 7 usuarios y 1 curso.
- En la copia aislada, con la base vacía, `restaurar.sh` tardó 83 segundos (unos 56 de arranque de la base nueva y unos 27 del volcado). Resultado: 6 usuarios, 1 curso, cero veces `posterior1`.
- `restaurar-archivos.sh`, con el volumen renombrado a `prueba_app`, tardó 114 segundos. Quedaron `app/config/configuration.php`, el tema `losangeles` y `app/courses/SEGOBRA/document/Documento-Ejemplo.pdf`. La copia respondió con el título «Constructora Los Angeles - Capacitacion».
- Tiempo total: unos 3,5 minutos. Se pierde todo lo hecho después de las 16:32. Es el límite de un respaldo diario.
- No se abrió la copia con login en el navegador: Chamilo redirige a `https://capacitacion.losangeles.internal`. Lo comprobado fue la base, los archivos y la respuesta HTTP.
- `posterior1` se borró del servidor definitivo al terminar. Volvió a haber 6 usuarios.

Captura: `docs/evidencias/int2/capturas/15-restauracion-copia-aislada.png`.

Tener un archivo en `~/respaldos` significa que existe una copia. Poder restaurar significa haber comprobado que esa copia recupera el sistema. Esta prueba es esa comprobación, hecha sin destruir el servidor en uso.

### Prueba anterior, del 30 y 31 de octubre

En la máquina de pruebas de esa etapa (antes de fijar la copia aislada como regla) sí se hizo `docker compose down -v` y se restauró encima.

- Respaldo del 30/10 a las 06:24: base de unos 44 KB y archivos de unos 351 MB. `gzip -t` y `tar -tzf` correctos. El log mostró `OK BD` y `OK ARCHIVOS`. Había 239 tablas y `curl -I http://127.0.0.1:8081` daba 200.
- Tras `down -v`, `restaurar.sh` sobre `chamilo-bd-2026-10-30_0624.sql.gz` recuperó 239 tablas y `restaurar-archivos.sh` dejó Chamilo otra vez en HTTP 200.
- El 31/10 se afinó el punto en el tiempo: se creó `respaldo_a`, se generó `chamilo-bd-2026-10-31_0501.sql.gz` (y su tar de archivos), después se creó `respaldo_b`, se hizo `down -v` y se restauró el par de las 05:01. Volvió `respaldo_a`, no apareció `respaldo_b`, siguieron 239 tablas y HTTP 200.

Esa prueba confirma el mismo límite: la restauración regresa al instante del respaldo. En el servidor definitivo el equivalente es el simulacro del 2 de noviembre, en la copia aislada.

---

## 13. Seguridad aplicada

- Contenedor de la base sin puertos publicados. `chamilo_user` limitado a la base `chamilo`.
- Balanceador solo en `127.0.0.1`. La entrada pública es Nginx con HTTPS.
- Cookie de sesión `ch_sid` con `HttpOnly`.
- `display_errors = Off`.
- Usuarios FTP en jaula: el intento de salir devuelve `550 Failed to change directory`. Sin acceso anónimo. Carpetas en modo 700.
- Secretos fuera del repositorio (`.env` con `chmod 600`, claves FTP por `passwd`, clave de rsync solo en Mint).
- MariaDB del sistema, resto de laboratorio, detenida y deshabilitada. Sus datos no se borraron.

Puntos débiles aceptados: FTP sin cifrar, certificado autofirmado, clave de la copia externa sin frase de paso, y una sola copia fuera del servidor.

---

## 14. Costos

Los montos que dependen de una cotización se dejan como fórmula. El prototipo reutilizó equipos y la red interna, así que el hardware adicional y el Internet adicional del prototipo académico son ₡0. Una solución libre sigue teniendo costo de implementación, hardware, electricidad, respaldos y administración.

### Licencias

Chamilo, MariaDB, Nginx, BIND9, vsftpd, Docker Engine y Linux: ₡0 de licencia cada uno. Total de licencias de los componentes principales: ₡0. Chamilo se distribuye bajo GPLv3+ ([chamilo.org](https://chamilo.org/es/chamilo/)). Docker Engine es código abierto bajo Apache 2.0 ([documentación del motor](https://docs.docker.com/engine/)).

Eso elimina el pago de licencia por usuario. El costo principal pasa a ser tiempo, electricidad, hardware e Internet.

### Hardware

Costo adicional del prototipo académico: ₡0, porque se reutilizó infraestructura.

Si la empresa compra equipo:

`costo inicial de hardware = precio del servidor + almacenamiento adicional + equipo de respaldo`

Ese precio queda pendiente de cotización. El proyecto no tiene una cotización real.

### Implementación

`costo de implementación = horas × tarifa técnica por hora`

Referencia oficial de salarios mínimos del sector privado para 2026, Ministerio de Trabajo y Seguridad Social ([lista 2026](https://www.mtss.go.cr/temas-laborales/salarios/lista_salarios_minimos_2026.pdf)):

- Trabajador en ocupación especializada: ₡16.244,50 por jornada diaria.
- Bachiller universitario: ₡664.078,07 mensuales.

Ejemplo de estructura, sin inventar la tarifa por hora: 20 horas × tarifa real del técnico o del proveedor. El monto final usa esa tarifa, no un número supuesto.

### Electricidad

La plataforma necesita el servidor encendido. En Costa Rica el cobro depende de los kWh y de la tarifa de la distribuidora ([ARESEP](https://aresep.go.cr/electricidad/tarifas/)).

`consumo mensual = kW × horas al día × días`
`costo mensual = kWh × tarifa aplicable`

Ejemplo con un equipo de 0,15 kW encendido todo el mes: 0,15 × 24 × 30 = 108 kWh. El costo es 108 × la tarifa vigente. No se fija una tarifa porque cambia según distribuidora, tipo de servicio y periodo.

### Internet

Dentro de la red interna, sin un enlace exclusivo para el servidor, el costo adicional es ₡0 si la empresa ya tiene conexión. Un enlace exclusivo queda pendiente de cotización con el proveedor.

### Respaldos y mantenimiento

Software de copia (rsync, SSH): ₡0 si se reutiliza una segunda máquina. El almacenamiento depende del disco y del crecimiento. Cada día se guardan unos 350 MB, con retención de 7 días (unos 2,5 GB) más la copia en Mint. Un disco nuevo queda pendiente de cotización.

Tareas periódicas: actualizar el sistema y los contenedores, revisar respaldos, probar una restauración, revisar espacio, mantener usuarios y cursos, y revisar certificado y configuración.

`costo mensual de mantenimiento = horas mensuales × tarifa`

Ejemplo de estructura: 4 horas al mes × tarifa técnica. La tarifa real la define quien dé el mantenimiento.

### Recurrentes de la plataforma

| Rubro | Monto |
|---|---|
| Licencias de los componentes libres | ₡0 |
| Electricidad | kWh × tarifa vigente |
| Internet | ₡0 adicional si se reutiliza la conexión |
| Mantenimiento | horas × tarifa |
| Almacenamiento de respaldos | según crecimiento del disco |
| Hardware | ₡0 si se reutiliza; si se compra, pendiente de cotización |
| Implementación inicial | horas × tarifa real |

Costos iniciales aparte de las licencias: instalación, posible compra de hardware, preparación de cursos, altas de usuarios y pruebas. Recurrentes: electricidad, mantenimiento, almacenamiento, Internet si hiciera falta un servicio extra, y actualización de contenidos.

### Frente a la capacitación presencial

Sin LMS, la empresa depende de sesiones presenciales y de listas en papel. Entran el tiempo del instructor, el tiempo de los trabajadores, el transporte, los materiales, el espacio, la alimentación, repetir la sesión para quienes faltaron y llevar el registro a mano.

`costo presencial = instructor + tiempo de los trabajadores + transporte + materiales + espacio + otros gastos`

Esos valores salen de datos internos o de una cotización. Quedan pendientes: instructor, transporte, materiales y espacio.

La plataforma convierte el curso en un recurso reutilizable: la misma capacitación se ofrece a alguien nuevo sin volver a pagar la sesión completa, los resultados quedan guardados, baja el uso de papel y se puede comprobar quién la hizo. El ahorro real depende del número de trabajadores, de cuántas capacitaciones haya y de cómo las use la empresa. Esos beneficios no son un ahorro automático.

Para una cifra definitiva hacen falta cotizaciones de hardware, mantenimiento, Internet y de la capacitación presencial.

---

## 15. Problemas que aparecieron y cómo se resolvieron

| Qué pasó | Causa | Qué se hizo |
|---|---|---|
| El instalador proponía una URL con `:80` | La instalación no pasó por el dominio HTTPS | Dejar la URL del portal en `https://capacitacion.losangeles.internal/` |
| MariaDB escuchando en `192.168.50.1:3306` | Resto de un laboratorio (11.8.6 instalada con apt) | `systemctl disable --now mariadb`, sin borrar sus datos |
| Nginx rechazaba archivos grandes | Límite por defecto de 1 MB | `client_max_body_size 100m`, igual que PHP |
| Avisos *deprecated* con PHP 8.3 | Chamilo 1.11 está pensado para PHP 7.4 | `error_reporting` en `chamilo.ini`. Sin errores fatales |
| `docker kill` no reinició la base | En esta versión de Docker ese comando no dispara el reinicio automático | Probar con `kill -9` del proceso `mariadbd` |
| Huecos de 23 s y de 3 min en las pruebas de HA | La VM se detiene y el reloj salta | Descartar esos tramos. No suspender el equipo en la demo |
| Respaldos solapados en la prueba cada minuto | El de archivos dura más de un minuto y cron no esperaba | `flock -n` |
| Los scripts de restauración pisarían el servidor | El volumen `chamilo_app` tiene nombre fijo | Simulacro solo en la copia aislada |
| Sin respaldos nocturnos del 3 al 6 de noviembre | El servidor estaba apagado a las 02:30 | Respaldo manual el 06/11 (13:09 a 13:50). Para el automático, la VM tiene que estar encendida |
| Mint perdió la llave, la carpeta y el crontab | Estado anterior de la VM | Rehacer la clave, la carpeta y el cron del apartado de copia externa |
| «Media del ejercicio 0 %» en el resumen del profesor | No se investigó | En la demo se muestra el informe de Ejercicios |
| El balanceador quedó un tiempo en `0.0.0.0:8081` | Hizo falta durante la instalación | Volver a `127.0.0.1:8081:80` y recrear el balanceador |

---

## 16. Respuestas de control

### Imagen, instalación y servidor (Integrante 2)

**¿Por qué el SHA-256 y por qué el `.env` no va a Git?**
El SHA-256 es la huella de `chamilo-1.11.40.zip`. El Dockerfile la compara con la registrada para comprobar que el zip es el oficial, que no se corrompió y que los cinco construyen la misma imagen. El `.env` tiene las contraseñas. Si entra a Git quedan en el historial aunque después se borre el archivo. En el repositorio solo está `.env.example`.

**¿Qué copia el Dockerfile, cuándo se reconstruye y por qué `display_errors = Off`?**
Parte de `php:8.3-apache`, instala las extensiones, descarga el paquete, revisa el SHA-256, lo deja en la carpeta web, crea `/sessions` y copia `chamilo.ini` y la configuración de Apache. Se reconstruye cuando cambia alguno de esos archivos o la versión de Chamilo o de PHP. `display_errors = Off` lo exige el instalador y evita mostrar rutas internas. Al agregar `session.cookie_httponly = 1` hubo que reconstruir y recrear el contenedor para que aplicara.

**¿Por qué Chamilo espera a que `bd` esté healthy, y por qué ninguno publica puertos?**
`bd` tiene healthcheck y Chamilo usa `depends_on` con `condition: service_healthy`, así el arranque no falla contra una base que todavía inicia. Los dos se ven por la red interna de Docker. A Chamilo se entra por el balanceador y por el Nginx del servidor. `docker compose port bd 3306` no muestra mapeo.

**¿Por qué se instala por el dominio, dónde queda la URL y por qué el host es `bd`?**
`root_web` se guarda en `app/config/configuration.php` y de ahí salen enlaces, redirecciones y estilos. Una URL equivocada hace que la plataforma apunte a una dirección que no existe. El instalador propuso una URL con `:80` y se cambió a `https://capacitacion.losangeles.internal/`. El host `bd` es el nombre del servicio. `localhost` sería el contenedor de Chamilo, que no tiene MariaDB.

**¿Qué riesgo tiene PHP 7.4 y por qué una imagen nueva no actualiza `chamilo_app`?**
PHP 7.4 ya no recibe parches. Si hubiera que usarlo, el contenedor seguiría sin exponerse (detrás de Nginx, en `127.0.0.1`) y el riesgo quedaría escrito. Aquí se usa 8.3. El volumen se llena con el código de la imagen solo cuando está vacío; después Docker no lo vuelve a copiar.

**¿Dónde quedó el logo y por qué sobrevive a `down`?**
En `chamilo_app`, en las rutas del tema `losangeles`. Un volumen con nombre no vive dentro del contenedor. Se comprobó con `down` y `up -d`, y también al restaurar la copia de prueba.

**¿Qué diferencia hay entre `down` y `down -v`, y qué guarda cada volumen?**
`down` borra contenedores y red. `down -v` borra también los volúmenes. `chamilo_datos_bd` es la base, `chamilo_app` es código, configuración, cursos, archivos, tema y logo, y `chamilo_sesiones` son las sesiones PHP compartidas. `down -v` solo se usó en copias de prueba.

### Base de datos (Integrante 4)

La versión 11.8 está fijada porque cada versión cambia reglas y dependencias. La base se crea en el primer arranque a partir de las variables `MARIADB_...`. Hay dos capas: el puerto 3306 solo dentro de Docker, y `chamilo_user` limitado a su base. El respaldo automático de los datos es el de las 02:30. Los comandos de estado, permisos, persistencia y monitoreo están en la sección 8.

### FTP, respaldos y copia (Integrante 5)

**¿Por qué FTP simple es inseguro?**
Usuario, contraseña y archivos viajan sin cifrar. Quien capture el tráfico puede leerlos. En producción: SFTP o FTPS.

**¿Por qué se respalda `chamilo_app` y no solo la base?**
La base no tiene los archivos físicos: configuración, cursos subidos, PDF, tema y logo. Con solo el SQL, Chamilo recuperaría registros y le faltarían esos archivos.

**¿Por qué cron necesita `exec -T`?**
Cron no tiene terminal. `-T` evita que Docker intente asignar una, y así `mariadb-dump` corre solo.

**¿Qué diferencia hay entre tener un respaldo y poder restaurar?**
Tener el archivo solo dice que la copia existe. Poder restaurar es haber borrado los datos de prueba y haber vuelto a levantar la plataforma desde esa copia. En octubre se hizo sobre la máquina de pruebas (`down -v`, 239 tablas, HTTP 200, `respaldo_a` presente y `respaldo_b` ausente). En noviembre se repitió en una copia aislada para no tocar el servidor definitivo.

**¿Qué cubre la copia externa que no cubre el cron local?**
El cron local deja los archivos en la misma VM. Si se pierde el disco o la máquina, se pierden sistema y respaldos juntos. La copia en Mint (`192.168.50.101`, `~/respaldos-losangeles/`) permite reconstruir el servidor. El procedimiento vigente es el de la sección 12: Mint obtiene la copia. La prueba de octubre, en la que el servidor empujaba los archivos, está en el anexo.

El bloque de documentación de esa etapa quedó marcado como en proceso: faltaba consolidar el manual, el diagrama y que otra persona siguiera la instalación desde cero. Este documento cierra esa consolidación con la arquitectura, el manual del servidor definitivo y el índice de evidencias.

---

## 17. Dónde está cada cosa en el repositorio

| Qué | Dónde |
|---|---|
| Compose, `.env.example`, Dockerfile, `chamilo.ini` | `docker/` |
| Logo y tema | `docker/personalizacion/` |
| Nginx del servidor | `nginx/capacitacion.conf` |
| Zona DNS | `dns/` |
| Respaldo, restauración y ejemplo de cron | `backups/` |
| FTP | `ftp/` |
| Prueba de HA, logs | `docs/evidencias/int2/ha-parada-una-replica.txt`, `ha-parada-ambas-replicas.txt`, `pruebas-ha-y-bd.md` |
| Simulacro de restauración | `docs/evidencias/int2/restauracion-simulacro.md` |
| Cron y copia externa | `docs/evidencias/int2/cron-y-copia-externa.md` |
| FTP del servidor definitivo | `docs/evidencias/int2/ftp-servidor-definitivo.md` |
| Capturas de la plataforma | `docs/evidencias/int2/capturas/` |
| Evidencias de MariaDB | `docs/evidencias/int4/` y `docs/PROCESSLIST.png` |
| Evidencias de FTP, respaldos y copia externa | `docs/evidencias/int5/` |
| Respuestas de control | `docs/guias/respuestas-int2.md`, `respuestas-int4.md`, `respuestas-int5.md`, `docs/guias/MariaDB/mariadb.md` |

Los documentos de origen (`arquitectura.md`, `instalacion.md`, `decisiones.md`, `versiones.md`, `software-libre.md`, `inventario-red.md`, `costos.md`, `respaldos.md`, `instrucciones-ftp.md`, `instrucciones-restauracion.md`, `monitoreo-bd.md`, `manual-int2-servidor-definitivo.md`, `documento-tecnico.md`) siguen en `docs/`. Este archivo es el que los ordena en un solo relato. `docs/documento-tecnico.docx` es la exportación del documento técnico y no agrega procedimientos distintos.

---

## 18. Límites y mejoras

- Puntos únicos de fallo: Nginx del servidor, MariaDB y la VM.
- Respaldo diario: se puede perder hasta un día de cambios. En una carga masiva, acortar la frecuencia.
- La copia externa depende de que Mint y el servidor estén encendidos a las 03:00. No hay tercera copia.
- FTP sin cifrar. Certificado autofirmado (el navegador avisa). Clave de rsync sin frase de paso.
- El cron del servidor no recupera las noches en que la VM estuvo apagada.
- Monitoreo descrito, sin alertas automáticas todavía.
- `docker kill` no demuestra el reinicio de MariaDB; la prueba válida es matar el proceso.

Mejoras razonables: replicación de la base, SFTP o FTPS, certificado de una CA interna, alertas de disco y de fallo de respaldo, una segunda copia externa, limitar la clave SSH con `command=` a solo `rsync`, y un temporizador del sistema que no dependa de que la VM esté encendida a una hora fija.

---

## Anexo. Procedimientos de octubre que el servidor definitivo reemplazó

Estos pasos se ejecutaron y quedaron documentados. El sistema que se demuestra en `serverdiego` usa las secciones 11 y 12.

**Cuentas FTP de esa etapa.** `ftp/crear-usuarios.sh`, en la redacción que siguieron `docs/instrucciones-ftp.md` y `docs/guias/respuestas-int5.md`, creaba `ftp_int1`, `ftp_int2`, `ftp_int3`, `ftp_int4`, `ftp_int5` y `ftp_instructor`. Se comprobaron con `getent passwd` y `ls -ld /home/ftp_int*`. Desde Mint se entró con `ftp 192.168.50.1` como `ftp_int2`, se subió `prueba.txt` a `subida/` y `cd /home/ftp_int3` devolvió `550 Failed to change directory`. En el servidor definitivo las cuentas son las de la sección 11 (`derek`, `dixon`, `joseth`, `ivan` y la cuenta ya existente `diego`), con la misma jaula y el mismo 550.

**Copia que empujaba el servidor.** En octubre Mint tenía OpenSSH Server y el cron de las 03:00 corría en el servidor:

```
0 3 * * * /usr/bin/rsync -av -e "ssh -i $HOME/.ssh/respaldo_cron_ed25519" $HOME/respaldos/ server@192.168.50.101:~/respaldos-losangeles/ >> $HOME/respaldos/rsync.log 2>&1
```

La clave se generó en el servidor (`ssh-keygen -t ed25519 -f ~/.ssh/respaldo_cron_ed25519 -N ""`) y se copió con `ssh-copy-id`. La prueba `ssh -o BatchMode=yes -i ~/.ssh/respaldo_cron_ed25519 server@192.168.50.101` respondió `SSH AUTOMATICO OK`. En las respuestas de control la copia de prueba usó `rsync` hacia `mint@192.168.50.101` y en Mint aparecieron, entre otros, `chamilo-bd-2026-10-30_0624.sql.gz` y `chamilo-archivos-2026-10-30_0624.tar.gz`. El candado de esa etapa era `/tmp/chamilo-respaldo.lock`. El 02/11 se cambió el sentido de la copia (la obtiene Mint) y el candado del servidor definitivo pasó a `/tmp/respaldo.lock`, que es el que quedó en `backups/crontab.txt`.

**`docs/instalacion.md` se corta** en la preparación de la carpeta destino de esa copia (`mkdir -p ~/resp`). El procedimiento completo vigente es el de las secciones 7 y 12 de este documento.

**Balanceador durante la instalación.** Un tiempo estuvo publicado como `8081:80`. La configuración final es `127.0.0.1:8081:80`, aplicada con `docker compose up -d --force-recreate balanceador`. `docker compose ps` debe mostrar `127.0.0.1:8081->80/tcp`.
