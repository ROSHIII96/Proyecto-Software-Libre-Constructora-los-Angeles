# Inventario de red y nombres

| Dato | Valor | Nota |
|---|---|---|
| Dominio de la zona | `losangeles.internal` | Dominio interno utilizado por el proyecto |
| Sitio de la plataforma | `capacitacion.losangeles.internal` | Dirección principal de Chamilo |
| Servidor principal | `192.168.50.1` | Servidor Ubuntu |
| Cliente Linux Mint | `192.168.50.101` | Cliente de pruebas y destino de respaldos |
| DNS | BIND9 | Resuelve la zona `losangeles.internal` |
| Nginx del servidor | Puertos 80 y 443 | 80 redirige a HTTPS; 443 funciona como proxy |
| Certificado HTTPS | `/etc/ssl/losangeles/` | Certificado autofirmado del proyecto |
| Balanceador Docker | `127.0.0.1:8081` | Solo accesible desde el servidor |
| Chamilo | Puerto 80 interno | No publica puertos directamente |
| MariaDB | Puerto 3306 interno | No publica puertos hacia la red |
| FTP | Puerto 21 | vsftpd |
| FTP pasivo | `40000-40100` | Rango configurado para conexiones pasivas |
| SSH servidor principal | Puerto 22 | Administración del servidor |
| SSH cliente Mint | Puerto 22 | Utilizado para copia externa de respaldos |
| Proyecto Docker | `chamilo` | Nombre utilizado por Docker Compose |
| Volumen de BD | `chamilo_datos_bd` | Persistencia de MariaDB |
| Volumen de aplicación | `chamilo_app` | Archivos persistentes de Chamilo |
| Volumen de sesiones | `chamilo_sesiones` | Sesiones compartidas de Chamilo |
| Respaldos locales | `~/respaldos` | Fuera de Docker y Git |
| Respaldos externos | `~/respaldos-losangeles/` | Almacenados en Linux Mint |

## Flujo de comunicación

El acceso principal sigue esta ruta:

Cliente Linux Mint

↓

DNS BIND9

↓

Nginx HTTPS del servidor

↓

127.0.0.1:8081

↓

Balanceador nginx dentro de Docker

↓

Réplicas de Chamilo

↓

MariaDB

## Consideraciones de seguridad

MariaDB no publica el puerto 3306 hacia la red externa.

Chamilo tampoco publica directamente su puerto 80.

El balanceador debe permanecer escuchando únicamente en:

127.0.0.1:8081

Durante algunas pruebas se publicó temporalmente el puerto 8081 hacia la red interna para facilitar la instalación y validación desde Linux Mint.

Al finalizar las pruebas debe restaurarse la configuración:

127.0.0.1:8081:80

Los respaldos externos se transfieren mediante SSH y rsync hacia Linux Mint.
