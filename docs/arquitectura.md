# Arquitectura del proyecto

Cliente Linux Mint
192.168.50.101

        |
        v

DNS BIND9
capacitacion.losangeles.internal

        |
        v

Nginx del servidor
Puertos 80 y 443
HTTPS

        |
        v

127.0.0.1:8081

        |
        v

Balanceador nginx en Docker

        |
   -------------
   |           |
   v           v

Chamilo 1   Chamilo 2

      \       /
       \     /
        v   v

      MariaDB
       11.8

        |
        v

Volúmenes persistentes:
- chamilo_datos_bd
- chamilo_app
- chamilo_sesiones


RESPALDOS

Servidor principal

        |
        v

~/respaldos

        |
        v

SSH + rsync

        |
        v

Linux Mint
192.168.50.101

        |
        v

~/respaldos-losangeles


FTP

vsftpd
Puerto 21
Puertos pasivos 40000-40100


## Descripción

El cliente accede a la plataforma mediante:

https://capacitacion.losangeles.internal

BIND9 resuelve el dominio interno.

Nginx recibe las conexiones HTTPS y las envía a:

127.0.0.1:8081

Ese puerto corresponde al balanceador nginx dentro de Docker.

El balanceador distribuye las solicitudes entre las réplicas de Chamilo.

Chamilo utiliza MariaDB como base de datos.

Los datos se guardan en volúmenes persistentes.

Los respaldos se generan en:

~/respaldos

Luego se copian automáticamente mediante SSH y rsync hacia:

192.168.50.101

en la carpeta:

~/respaldos-losangeles

El servicio FTP utiliza vsftpd con usuarios aislados.

## Puntos únicos de fallo

Los principales puntos únicos de fallo son:

- Nginx del servidor
- MariaDB
- La máquina virtual principal

Las réplicas de Chamilo permiten mantener la aplicación disponible si una instancia falla.
