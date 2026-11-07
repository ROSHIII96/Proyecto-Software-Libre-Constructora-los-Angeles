# Respuestas de Control y Evidencias — Integrante 1 (Dixon)

**Proyecto:** Constructora Los Ángeles — Chamilo LMS  
**Servicios:** DNS (BIND9), Certificados SSL SAN, Nginx Reverse Proxy  
**Rama:** `main` (fusionado) / `int1-dns-https`  

---

## 🟢 Bloque 1: Zona DNS Nueva (`losangeles.internal`)

### 📸 Punto de Control 1
- **Servidor:** Salida de `sudo named-checkzone losangeles.internal /etc/bind/db.losangeles.internal` confirmando estado `OK`.
- **Servidor:** Salida del comando `dig @192.168.50.1 capacitacion.losangeles.internal` mostrando la bandera `aa` (Authoritative Answer), `status: NOERROR` y la dirección IP `192.168.50.1` en la sección `ANSWER`.
- **Cliente (Linux Mint):** Salida del comando `getent hosts capacitacion.losangeles.internal` resolviendo correctamente a la IP `192.168.50.1`.

### ❓ Pregunta de Control 1
**¿Qué decide el DNS y qué decide el VirtualHost (Server Block) cuando alguien escribe el nombre? ¿Qué pasa si falta uno de los dos?**

* **El DNS (BIND9):** Resuelve la ubicación de red. Se encarga de traducir el nombre de dominio legible (`capacitacion.losangeles.internal`) en la dirección IP destino (`192.168.50.1`). No procesa páginas web, ni certificados, ni puertos de aplicaciones.
* **El Server Block (Nginx):** Resuelve el servicio interno y la seguridad web. Recibe la petición en los puertos HTTP (80) o HTTPS (443), evalúa la directiva `server_name`, aplica el cifrado mediante el certificado SSL y redirige la solicitud hacia el contenedor o servicio interno mediante `proxy_pass http://127.0.0.1:8081`.
* **¿Qué ocurre si falta uno de los dos?**
  * **Sin DNS:** El cliente o navegador web no puede determinar a qué dirección IP conectarse y genera el error *"Servidor no encontrado / Server Not Found"*.
  * **Sin Nginx (Server Block):** El tráfico llega con éxito a la IP del servidor, pero al no haber un bloque que procese ese dominio específico, el servidor responde con un error `404 Not Found`, un fallo `502 Bad Gateway` o la página predeterminada.

---

## 🟡 Bloque 2: Certificado Autofirmado (SAN)

### 📸 Punto de Control 2
- **Inspección del certificado:** Salida del comando `sudo openssl x509 -in /etc/ssl/losangeles/capacitacion.crt -noout -subject -dates -ext subjectAltName` donde se observa el Subject, el periodo de validez (365 días) y la extensión `DNS:capacitacion.losangeles.internal`.
- **Permisos de seguridad:** Salida de `sudo ls -l /etc/ssl/losangeles/capacitacion.key` comprobando que la clave privada posee permisos restrictivos (`-rw-------` pertenencia de `root`).

### ❓ Pregunta de Control 2
**¿Por qué un certificado autofirmado cifra igual pero el navegador advierte? ¿Para qué sirve el `subjectAltName`?**

* **Cifrado vs. Autenticidad:** La llave privada RSA de 2048 bits realiza un cifrado idéntico al de un certificado comercial emitido por una entidad de pago (los datos viajan 100% protegidos e incomprensibles en tránsito). La advertencia de seguridad en el navegador aparece porque el certificado fue firmado por nosotros mismos y no por una Autoridad Certificadora (CA) pública de confianza (como Let's Encrypt o DigiCert) que certifique externamente la identidad del dominio.
* **Uso del `subjectAltName` (SAN):** Los navegadores modernos rechazan certificados que dependen únicamente del campo clásico `Common Name` (CN). La extensión SAN especifica explícitamente cuáles nombres de dominio (`losangeles.internal`) y subdominios (`capacitacion.losangeles.internal`) cubre el certificado de forma válida.

---

## 🔵 Bloque 3: Server Block Nginx HTTPS con Proxy Inverso

### 📸 Punto de Control 3
- **Verificación de sintaxis:** Salida del comando `sudo nginx -t` confirmando `syntax is ok` y `test is successful`.
- **Navegación segura:** Captura en la VM cliente (Linux Mint) navegando a la URL `https://capacitacion.losangeles.internal` mostrando la respuesta del servicio web.

### ❓ Pregunta de Control 3
**¿Para qué sirven `proxy_set_header Host` y `proxy_set_header X-Forwarded-Proto` en Nginx? ¿Qué se rompería en Chamilo si creyera que el cliente usó HTTP?**

* **`proxy_set_header Host $host;`:** Le transmite a la aplicación web dentro del contenedor el nombre del dominio original solicitado por el usuario (`capacitacion.losangeles.internal`), impidiendo que reciba `127.0.0.1` como nombre de host.
* **`proxy_set_header X-Forwarded-Proto https;`:** Notifica formalmente a la plataforma de que el cliente se conectó originalmente a través de un protocolo seguro **HTTPS (puerto 443)**, a pesar de que el tramo interno entre Nginx y el contenedor viaja por HTTP.
* **¿Qué se rompería en Chamilo?**
  * Chamilo evalúa la función PHP `api_is_https()`, la cual inspecciona precisamente la cabecera `X-Forwarded-Proto`.
  * Si la plataforma creyera que el cliente se conectó por HTTP, generaría las rutas absolutas de hojas de estilo (CSS), archivos JavaScript y formularios con prefijo `http://`, desencadenando errores de **Contenido Mixto (Mixed Content)** o un **bucle infinito de redirecciones 301/302**.
  * *Ajuste técnico adicional:* Se configuró `client_max_body_size 100m;` y `proxy_read_timeout 300s;` en el bloque de Nginx para permitir el envío e instalación de paquetes y recursos pesados sin bloqueos por el servidor web.

---

## 🟠 Bloque 4: Redirección 80 ➔ 443 y Exposición Mínima

### 📸 Punto de Control 4
- **Comprobación de redirección:** Salida del comando `curl -I http://capacitacion.losangeles.internal` devolviendo una respuesta con código `HTTP/1.1 301 Moved Permanently` apuntando hacia `Location: https://capacitacion.losangeles.internal/`.
- **Auditoría de puertos:** Salida de `sudo ss -tulpn | grep -E ':(53|80|443|8081|3306)'` demostrando que **únicamente los puertos 80 y 443 (Nginx) y 53 (BIND9)** están expuestos públicamente. El puerto `8081` escucha exclusivamente en `127.0.0.1:8081` y el puerto de base de datos (`3306`) no se encuentra publicado externamente.

### ❓ Pregunta de Control 4
**¿Por qué el contenedor se publica en `127.0.0.1:8081` y no en `0.0.0.0:8081`? ¿Y por qué la base de datos no lleva `ports`?**

* **`127.0.0.1:8081` vs `0.0.0.0:8081`:** Vincular el contenedor a la interfaz local `127.0.0.1` aplica el principio de **Superficie de Ataque Mínima**. Si se publicara en `0.0.0.0`, cualquier usuario de la red podría saltearse el Proxy Inverso Nginx y la capa de cifrado SSL conectándose de forma no segura directamente a `http://192.168.50.1:8081`.
* **Ausencia de `ports` en MariaDB:** La base de datos y la aplicación Chamilo se comunican internamente por medio de la red virtual privada del Docker Compose (`chamilo_net`). Publicar el puerto `3306` hacia el exterior expondría la base de datos a ataques o escaneos desde la red empresarial sin ninguna necesidad operativa.

---

## 🟣 Bloque 5: Justificación Escrita de Arquitectura (`docs/decisiones.md`)

Se integró en la documentación del proyecto el siguiente párrafo justificativo de las decisiones de diseño tomadas:

> *"Se implementó **Nginx como Proxy Inverso de entrada** (escuchando en los puertos 80 y 443 con redirección obligatoria a HTTPS y proxy hacia `127.0.0.1:8081`) debido a los siguientes criterios técnicos:*
>
> 1. **Gestión centralizada del cifrado SSL:** Al trabajar con réplicas de la aplicación, el certificado SSL habita en un único punto (Nginx), evitando tener que instalar, distribuir y actualizar certificados dentro de cada contenedor.
> 2. **Superficie de ataque reducida:** El puerto `8081` de la aplicación queda restringido al host local (`127.0.0.1`) y la base de datos MariaDB no expone puertos fuera de la red interna de Docker.
> 3. **Gestión de tráfico pesado:** Permite ajustar en el Proxy directivas globales como `client_max_body_size 100m;` para soportar cargas pesadas de archivos en la plataforma de capacitación.
> 4. **Compatibilidad:** Chamilo reconoce el entorno seguro mediante la cabecera `X-Forwarded-Proto` enviada por Nginx.
> 5. **Trade-off:** Nginx actúa como un **Punto Único de Fallo (SPOF)**; si el proceso de Nginx se detiene, el acceso HTTPS hacia los contenedores web queda interrumpido."*