# Guía de instalación desde cero: DNS BIND9, SSL SAN y proxy inverso Nginx

**Proyecto:** Constructora Los Ángeles — Chamilo LMS  
**Responsable:** Dixon (Integrante 1)  
**Dominio interno:** `losangeles.internal`  
**Sitio de capacitación:** `capacitacion.losangeles.internal`  
**Servidor Ubuntu:** `192.168.50.1`  
**Cliente Linux Mint:** `192.168.50.101`

## 0. Antes de empezar

Esta guía parte de un Ubuntu Server recién instalado, sin Git, BIND9, Nginx ni OpenSSL configurados. Para que el proxy entregue Chamilo, **también tiene que existir el proyecto Docker funcionando en `127.0.0.1:8081`**. Hasta ese momento, Nginx puede devolver `502 Bad Gateway`: eso no significa necesariamente que el proxy esté mal configurado.

Realizar los pasos 1 a 8 en **Ubuntu Server**. El paso 9 se realiza en **Linux Mint**.

> **Precaución:** si el servidor tiene otros laboratorios o sitios Apache, detener Apache interrumpirá esos sitios. No ejecutar `docker compose down -v` en un entorno con datos que deban conservarse.

## 1. Configurar y comprobar la red del servidor

La VM Ubuntu debe tener conectividad de red y una interfaz en la red interna `192.168.50.0/24`.

```bash
ip -br a
ip route
```

Debe verse `192.168.50.1/24` en alguna interfaz de red. Si no aparece, hay que configurar esa interfaz en Netplan según el **nombre real de la interfaz** (`enp0s8`, por ejemplo). No copiar un nombre supuesto.

Comprobar además el acceso a repositorios:

```bash
ping -c 3 1.1.1.1
```

Si no existe conexión, revisar los adaptadores de VirtualBox (por ejemplo, NAT para Internet y red interna para comunicar Ubuntu con Mint) antes de instalar paquetes.

## 2. Instalar herramientas en Ubuntu Server

```bash
sudo apt update
sudo apt install -y git curl wget nano openssl dnsutils bind9 bind9-utils nginx
```

Verificar:

```bash
git --version
openssl version
named -v
nginx -v
```

Habilitar BIND9:

```bash
sudo systemctl enable --now named
sudo systemctl status named --no-pager
```

El estado esperado es `active (running)`.

## 3. Clonar o actualizar el repositorio

Si **no existe** `~/proyecto-eif431o`:

```bash
cd ~
git clone https://github.com/ROSHIII96/Proyecto-Software-Libre-Constructora-los-Angeles.git proyecto-eif431o
```

Si **ya existe**, revisar primero los cambios locales para no perderlos:

```bash
cd ~/proyecto-eif431o
git status
git branch --show-current
```

Solo si estás en `main` y sin cambios locales pendientes:

```bash
git pull origin main
```

La guía también puede ejecutarse de manera independiente del repositorio creando los archivos de configuración manualmente.

## 4. Configurar BIND9 y la zona interna

Respaldar el archivo actual:

```bash
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak
sudo nano /etc/bind/named.conf.local
```

Agregar **una sola vez** la declaración de zona (sin borrar otras zonas válidas):

```conf
zone "losangeles.internal" {
    type master;
    file "/etc/bind/db.losangeles.internal";
};
```

Crear el archivo de zona:

```bash
sudo nano /etc/bind/db.losangeles.internal
```

Contenido:

```dns
$TTL 86400
@ IN SOA ns1.losangeles.internal. admin.losangeles.internal. (
    2026110401
    3600
    1800
    604800
    86400
)
@            IN NS ns1.losangeles.internal.
ns1          IN A 192.168.50.1
@            IN A 192.168.50.1
capacitacion IN A 192.168.50.1
www          IN A 192.168.50.1
ftp          IN A 192.168.50.1
```

> Cada vez que se modifique la zona, incrementar el número de **serial**. En este ejemplo se utiliza el formato fecha más revisión.

Validar antes de reiniciar:

```bash
sudo named-checkconf
sudo named-checkzone losangeles.internal /etc/bind/db.losangeles.internal
```

La segunda prueba debe terminar en `OK`. Aplicar:

```bash
sudo systemctl restart named
sudo systemctl status named --no-pager
```

Probar respuestas:

```bash
dig @192.168.50.1 capacitacion.losangeles.internal +short
dig @192.168.50.1 www.losangeles.internal +short
dig @192.168.50.1 ftp.losangeles.internal +short
```

Cada consulta debe devolver `192.168.50.1`. Si aparece `NXDOMAIN`, revisar que la zona esté declarada, que el archivo exista y que `named-checkzone` termine sin errores.

## 5. Crear certificado SSL autofirmado con SAN

```bash
sudo mkdir -p /etc/ssl/losangeles
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/losangeles/capacitacion.key \
  -out /etc/ssl/losangeles/capacitacion.crt \
  -subj "/CN=capacitacion.losangeles.internal" \
  -addext "subjectAltName=DNS:capacitacion.losangeles.internal,DNS:www.losangeles.internal,DNS:ftp.losangeles.internal,IP:192.168.50.1"
sudo chmod 600 /etc/ssl/losangeles/capacitacion.key
```

Verificar nombres alternativos:

```bash
openssl x509 -in /etc/ssl/losangeles/capacitacion.crt -noout -text | grep -A2 "Subject Alternative Name"
```

El certificado es **autofirmado**: proporciona cifrado, pero el navegador advertirá que no proviene de una autoridad de confianza. En una implementación real se debe usar una autoridad interna confiable o un certificado emitido para un dominio apropiado.

## 6. Dejar libre el puerto 80/443 para Nginx

Consultar quién escucha:

```bash
sudo ss -ltnp | grep -E ':(80|443)\b' || true
```

Si aparece Apache y este servidor se dedicará a Nginx, detenerlo (no es obligatorio desinstalarlo):

```bash
sudo systemctl disable --now apache2
```

Comprobar otra vez los puertos. Si ya están ocupados por Nginx, no hace falta detenerlo.

## 7. Crear el proxy inverso HTTPS en Nginx

Abrir el archivo:

```bash
sudo nano /etc/nginx/sites-available/capacitacion.conf
```

Pegar:

```nginx
server {
    listen 80;
    server_name capacitacion.losangeles.internal;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name capacitacion.losangeles.internal;

    ssl_certificate /etc/ssl/losangeles/capacitacion.crt;
    ssl_certificate_key /etc/ssl/losangeles/capacitacion.key;

    client_max_body_size 100m;
    proxy_read_timeout 300s;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
    }
}
```

Activar el sitio y retirar el sitio predeterminado de Nginx (solo el enlace de configuración):

```bash
sudo ln -sf /etc/nginx/sites-available/capacitacion.conf /etc/nginx/sites-enabled/capacitacion.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

**Solo si la validación es exitosa**:

```bash
sudo systemctl enable --now nginx
sudo systemctl reload nginx
sudo systemctl status nginx --no-pager
```

## 8. Verificar Docker y el proxy en Ubuntu Server

Este paso supone que otro integrante ya preparó `docker/docker-compose.yml`, la imagen de Chamilo y el archivo `.env`. Si **no tienes Docker**, primero necesitas instalar Docker Engine y el plugin Compose siguiendo la documentación oficial: https://docs.docker.com/engine/install/ubuntu/ . No basta con instalar Nginx para que Chamilo exista.

Con Docker y el proyecto ya configurados:

```bash
cd ~/proyecto-eif431o/docker
docker compose config --services
docker compose up -d
docker compose ps
```

Los servicios esperados son `bd`, `chamilo` y `balanceador`. Revisar que el puerto de balanceador en `docker-compose.yml` esté limitado al servidor:

```yaml
ports:
  - "127.0.0.1:8081:80"
```

Prueba local directa:

```bash
curl -I http://127.0.0.1:8081
```

Prueba del proxy sin depender del DNS del propio Ubuntu:

```bash
curl -k -I --resolve capacitacion.losangeles.internal:443:192.168.50.1 https://capacitacion.losangeles.internal
```

Comprobar la redirección HTTP:

```bash
curl -I --resolve capacitacion.losangeles.internal:80:192.168.50.1 http://capacitacion.losangeles.internal
```

Debe aparecer una redirección `301` hacia HTTPS. La prueba HTTPS suele devolver `200` o una redirección legítima de Chamilo. Un `502` normalmente indica que el balanceador o Chamilo no están accesibles en `127.0.0.1:8081`.

Si la página carga sin estilos y en el navegador hay errores de recursos bloqueados, comprobar que la URL base de Chamilo use `https://capacitacion.losangeles.internal/` y no una IP o `http://...:8081` anterior.

## 9. Configurar el cliente Linux Mint

En Mint, comprobar su dirección:

```bash
ip -br a
ping -c 3 192.168.50.1
```

Para probar directamente contra BIND9:

```bash
nslookup capacitacion.losangeles.internal 192.168.50.1
```

Debería devolver `192.168.50.1`.

La consulta anterior **no configura el DNS predeterminado** de Mint. Para abrir el sitio por nombre, configurar en NetworkManager el DNS de la interfaz de red interna con `192.168.50.1`, sin quitar de forma indiscriminada otras conexiones necesarias. Como prueba temporal de resolución de nombres también se puede usar `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Agregar si no existe:

```text
192.168.50.1 capacitacion.losangeles.internal
```

Esa solución temporal no sustituye comprobar que Mint use BIND9 cuando el proyecto exige DNS real.

Desde Mint:

```bash
curl -k -I https://capacitacion.losangeles.internal
```

En Firefox abrir:

```text
https://capacitacion.losangeles.internal:443
```

**Nota:** `:443` es opcional porque HTTPS usa ese puerto por defecto. No usar `192.168.50.1:8081` desde Mint cuando Docker publica `8081` únicamente en `127.0.0.1`.

## 10. Auditoría y solución de problemas

Estado de servicios:

```bash
sudo systemctl status named --no-pager
sudo systemctl status nginx --no-pager
```

Puertos:

```bash
sudo ss -ltnp | grep -E ':(53|80|443|8081)\b'
```

Resultados esperados:

- Puerto `53`: BIND9 (`named`).
- Puertos `80` y `443`: Nginx del host.
- Puerto `8081`: proxy Docker en `127.0.0.1` únicamente.

Diagnósticos útiles:

```bash
sudo journalctl -u named -n 30 --no-pager
sudo journalctl -u nginx -n 30 --no-pager
sudo nginx -t
dig @192.168.50.1 capacitacion.losangeles.internal +short
cd ~/proyecto-eif431o/docker && docker compose ps
```

**Casos frecuentes:**

- `NXDOMAIN`: revisar declaración y contenido de la zona BIND9.
- `nginx.service not found`: Nginx no está instalado.
- `Address already in use` en 80/443: Apache u otro proceso ocupan los puertos.
- `502 Bad Gateway`: Nginx no llega al balanceador en `127.0.0.1:8081`.
- Página sin CSS: verificar la URL base y los encabezados de proxy, y revisar la consola de Firefox.
- Advertencia de certificado: esperada con un certificado autofirmado que aún no es de confianza para Mint.

## 11. Evidencias recomendadas para la entrega

1. `ip -br a` del Ubuntu Server mostrando `192.168.50.1`.
2. `named-checkconf` y `named-checkzone` con resultado `OK`.
3. Consultas `dig` de los tres subdominios.
4. Certificado mostrando los SAN con OpenSSL.
5. `nginx -t` correcto y `systemctl status nginx` activo.
6. `docker compose ps` mostrando servicios saludables.
7. `curl -I` de HTTP con redirección a HTTPS y prueba HTTPS.
8. Captura de Chamilo abierto desde Linux Mint.

## 12. Comandos para guardar la guía en GitHub

Una vez que el archivo esté dentro de `~/proyecto-eif431o/docs/`:

```bash
cd ~/proyecto-eif431o
git status
git add docs/instrucciones-dns-ssl-nginx.md
git commit -m "Agrega guia de instalacion DNS SSL y Nginx desde cero"
git push origin Derek-FTP
```

Si vas a trabajar en la rama de Dixon o ya estás en otra rama, ajusta el destino del `push` y nunca reemplaces cambios ajenos sin revisarlos.
