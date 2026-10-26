# Integrante 1 — Coordinación, DNS (BIND9), certificado y Apache con HTTPS

**Rama:** `int1-dns-https` · **Evidencias:** `docs/evidencias/int1/` · **Respuestas:** `docs/guias/respuestas-int1.md`

## Objetivo

Que el dominio del proyecto entre por Apache con HTTPS y llegue a la plataforma que corre en Docker: **nombre → IP (BIND9) → VirtualHost con certificado → proxy al contenedor**. Es el Bloque 5 del Lab. #5 aplicado al proyecto, más la coordinación de la integración.

## Antes de empezar

- VM Servidor con la topología del curso: `enp0s3` (NAT) y `enp0s8` (red interna) con `192.168.50.1/24`; DHCP activo; Mint como cliente (Sesiones 6 y 7).
- BIND9 y Apache ya instalados (Sesiones 7 y 8). Los sitios de los laboratorios anteriores **no se tocan**: esta zona, este certificado y este VirtualHost son nuevos.
- Repositorio clonado en `~/proyecto-eif431o` y rama creada (guía común, sección 3).
- **No necesita esperar a nadie:** hasta que exista la plataforma, prueba con un servidor temporal en el 8081, como en la Sesión 7.

## Bloque 1 — Zona DNS nueva: `losangeles.internal` (≈ 15 min)

**Qué va a hacer y por qué.** Crea una zona propia con el nombre del sitio. El repositorio ya trae el archivo de zona y el bloque para `named.conf.local`; usted debe poder explicar cada línea.

1. Copie el archivo de zona y declare la zona (al **final** de `named.conf.local`, sin borrar las anteriores).

```bash
cd ~/proyecto-eif431o
sudo cp dns/db.losangeles.internal /etc/bind/db.losangeles.internal
sudo tee -a /etc/bind/named.conf.local < dns/named.conf.local.ejemplo
ls -l /etc/bind/db.losangeles.internal
```

*Qué hace:* `cp` instala el archivo de zona; `tee -a` agrega la declaración al final sin sobrescribir; `ls -l` confirma que el archivo es legible por el usuario `bind`.

2. Valide **antes** de reiniciar, reinicie y consulte.

```bash
sudo named-checkconf
sudo named-checkzone losangeles.internal /etc/bind/db.losangeles.internal
sudo systemctl restart named
sudo systemctl status named --no-pager
dig @192.168.50.1 capacitacion.losangeles.internal
dig @192.168.50.1 www.losangeles.internal +short
```

*Qué debe ver:* `named-checkzone` termina en **OK**; `status` en **active (running)**; en el primer `dig` la bandera `aa`, `status: NOERROR` y `192.168.50.1` en ANSWER; el segundo imprime el alias (`capacitacion.losangeles.internal.`) y la IP.

3. En **Mint**, compruebe que el cliente resuelve (el DHCP ya le entrega `192.168.50.1` como DNS desde la Sesión 7).

```bash
getent hosts capacitacion.losangeles.internal
```

> **Punto de control 1 (sí/no):** captura del servidor con `named-checkzone … OK` y el `dig` con `NOERROR`/`aa`, y captura de Mint con `getent hosts` mostrando `192.168.50.1`.

**Pregunta de control:** ¿Qué decide el DNS y qué decide el VirtualHost cuando alguien escribe el nombre? ¿Qué pasa si falta uno de los dos?

## Bloque 2 — Certificado autofirmado (≈ 10 min)

**Qué va a hacer y por qué.** Un certificado propio para `capacitacion.losangeles.internal`. Cifra igual que uno comercial; lo único que falta es un tercero que garantice quién es el dominio, por eso el navegador advierte.

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/capacitacion.key \
  -out /etc/ssl/certs/capacitacion.crt \
  -subj "/C=CR/O=Constructora Los Angeles/CN=capacitacion.losangeles.internal" \
  -addext "subjectAltName=DNS:capacitacion.losangeles.internal"

sudo openssl x509 -in /etc/ssl/certs/capacitacion.crt -noout -subject -dates -ext subjectAltName
sudo ls -l /etc/ssl/private/capacitacion.key
```

*Qué hace:* es el comando de la Sesión 9 con dos agregados: `-subj` evita las preguntas interactivas y `subjectAltName` hace que los navegadores modernos reconozcan el nombre (solo con `CN` algunos lo rechazan). *Qué debe ver:* el `subject` con el dominio, las fechas de validez y el `DNS:` del SAN; la llave con permisos `-rw-------`.

> **Punto de control 2 (sí/no):** captura de la salida del segundo comando y del `ls -l` de la llave.

**Pregunta de control:** ¿Por qué un certificado autofirmado cifra igual pero el navegador advierte? ¿Para qué sirve el `subjectAltName`?

## Bloque 3 — VirtualHost HTTPS con proxy (≈ 20 min)

**Qué va a hacer y por qué.** Apache recibe HTTPS en el 443 y reenvía al contenedor que, en el proyecto, se publica **solo en `127.0.0.1:8081`**. Sustituye al `DocumentRoot`: aquí Apache no sirve archivos, hace de proxy inverso.

1. Módulos y sitio (el archivo está en `apache/capacitacion.conf`; léalo completo antes de copiarlo).

```bash
sudo a2enmod ssl proxy proxy_http headers
sudo systemctl restart apache2
sudo cp ~/proyecto-eif431o/apache/capacitacion.conf /etc/apache2/sites-available/capacitacion.conf
sudo a2ensite capacitacion.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

*Qué hace:* los módulos permiten reenviar (`proxy`, `proxy_http`) y agregar cabeceras (`headers`). Las dos líneas clave: `ProxyPreserveHost On` hace que la aplicación reciba el nombre del dominio y no `127.0.0.1`; `RequestHeader set X-Forwarded-Proto "https"` le avisa que el cliente usó HTTPS aunque el último tramo sea HTTP (**Chamilo lo necesita**: su función `api_is_https()` lee exactamente esa cabecera).

2. Pruébelo **sin Docker**, con el servidor temporal del 8081.

```bash
mkdir -p ~/prueba-web && cd ~/prueba-web
echo '<h1>Proxy OK</h1>' > index.html
python3 -m http.server 8081 --bind 127.0.0.1
```

*Qué debe ver:* en Mint, `https://capacitacion.losangeles.internal` (acepte la advertencia del certificado) muestra **Proxy OK**, con la URL visible. Detenga el servidor con `Ctrl+C`. Si ya hay un contenedor en el 8081 (la plataforma o el `~/lab5`), pruebe con ese.

> **Punto de control 3 (sí/no):** (a) `sudo cat /etc/apache2/sites-available/capacitacion.conf`; (b) `apache2ctl configtest` con **Syntax OK**; (c) captura de Mint con la URL `https://capacitacion.losangeles.internal` y la página.

**Pregunta de control:** ¿Para qué sirven `ProxyPreserveHost` y `X-Forwarded-Proto`? ¿Qué se rompería en Chamilo si la plataforma creyera que el cliente usó HTTP?

## Bloque 4 — Redirección 80 → 443 y exposición mínima (≈ 10 min)

**Qué va a hacer y por qué.** El VirtualHost del puerto 80 ya redirige a HTTPS. Ahora compruebe que **solo Apache** queda expuesto: la aplicación en `127.0.0.1` y la base de datos sin puertos publicados (regla final del Lab. #5).

```bash
curl -sI --resolve capacitacion.losangeles.internal:80:127.0.0.1 http://capacitacion.losangeles.internal/ | head -3
sudo ss -tlnp | grep -E ':(80|443|8081|3306) '
```

*Qué debe ver:* `301 Moved Permanently` con `Location: https://capacitacion.losangeles.internal/`. En `ss`: Apache en 80 y 443; el 8081 **solo** como `127.0.0.1:8081` cuando la plataforma esté arriba; **nada** en el 3306. Repita esta comprobación el día de la integración con todo levantado.

> **Punto de control 4 (sí/no):** captura de ambos comandos (la del `ss` con la plataforma ya levantada, el día de la integración). Desde Mint, `http://192.168.50.1:8081` no responde.

**Pregunta de control:** ¿Por qué el contenedor se publica en `127.0.0.1:8081` y no en `0.0.0.0:8081`? ¿Y por qué la base de datos no lleva `ports`?

## Bloque 5 — Justificación escrita: proxy o HTTPS en el contenedor (≈ 15 min)

La consigna dice que se evalúa que pueda **justificar** la elección. Escriba en `docs/decisiones.md` un párrafo con estos puntos y sus propias palabras:

1. Con dos réplicas, el certificado vive en **un solo lugar** (Apache); dentro de los contenedores habría que copiarlo a cada una y renovarlo en todas.
2. Los contenedores hablan HTTP solo por la red interna y no se publican hacia afuera (superficie mínima).
3. Es el patrón visto y evaluado en el Lab. #5: cualquiera puede reproducirlo.
4. Chamilo lo soporta: lee `X-Forwarded-Proto` (`api_is_https()` en `main/inc/lib/api.lib.php`).
5. **Trade-off:** hay un salto más y un servicio más que mantener; si Apache cae, no hay HTTPS (punto único de fallo que se documenta, no se oculta).

> **Punto de control 5 (sí/no):** el párrafo en `docs/decisiones.md` (PR).

## Bloque 6 — Coordinación e integración (todo el período)

1. **Inventario de red:** mantenga `docs/inventario-red.md` (dominio, IP, puertos, volúmenes). Si en la integración la IP cambia, se cambia **en un solo orden**: zona DNS (con serial +1), DHCP (`domain-name-servers`), inventario.
2. **Diagrama de infraestructura:** con el Integrante 5, convierta el esquema de la guía común en un diagrama limpio (`docs/arquitectura.md`).
3. **Despliegue desde cero (jueves 29 y viernes 30):** en una VM limpia, siga **solo** el repositorio y esta lista; anote cada tropiezo en `docs/decisiones.md`:

| # | Comprobación | Responsable del arreglo si falla |
|---|---|---|
| 1 | `enp0s8` con `192.168.50.1`; Mint recibe IP y DNS por DHCP | Int. 1 |
| 2 | `dig` y `getent` resuelven `capacitacion.losangeles.internal` | Int. 1 |
| 3 | HTTPS responde y el 80 redirige | Int. 1 |
| 4 | `docker compose up -d --build` termina con `bd`, `chamilo` y `balanceador` *healthy* | Int. 2 |
| 5 | Chamilo instalado por el dominio HTTPS; login de administrador | Int. 2 |
| 6 | `--scale chamilo=2` y prueba de caída | Int. 3 |
| 7 | Cuentas FTP y prueba de aislamiento | Int. 5 |
| 8 | Respaldo por Cron + restauración comprobada | Int. 5 y 4 |
| 9 | `ss` muestra solo Apache expuesto | Int. 1 |
| 10 | Evidencias de todos en `docs/evidencias/` | cada uno |

4. **Ensayo del 6/11:** guion con tiempos, un responsable por componente y banco de preguntas (use las "preguntas de control" de las cinco guías).

## Extra (opcional, mejora la demo)

Para que el navegador no advierta: copie `capacitacion.crt` a Mint e impórtelo en Firefox (*Ajustes → Privacidad y seguridad → Ver certificados → Autoridades → Importar*). Es un paso de demostración; la explicación de por qué el certificado es autofirmado sigue siendo la del Bloque 2.

## Si algo falla

- **`dig` sin respuesta o `REFUSED`:** olvidó el `@192.168.50.1`, o el dominio termina en `.local` (aquí es `.internal`).
- **`named-checkzone` marca error:** falta el punto final en un nombre completo (`ns1.losangeles.internal.`) o el `file` de `named.conf.local` no coincide con la ruta real.
- **Cambió la zona y nadie lo nota:** no subió el *Serial*.
- **`Invalid command 'ProxyPass'`:** falta `sudo a2enmod proxy proxy_http` y reiniciar Apache.
- **`502 Bad Gateway`:** el contenedor no está arriba o el puerto no coincide; pruebe `curl -I http://127.0.0.1:8081` en el servidor.
- **Chamilo carga sin estilos o redirige a `http://`:** se instaló por una URL distinta de `https://capacitacion.losangeles.internal/`. La URL de instalación queda grabada (`root_web` en `app/config/configuration.php`); corríjala o reinstale por el dominio correcto.
- **El navegador advierte del certificado:** es lo esperado con un certificado autofirmado.
