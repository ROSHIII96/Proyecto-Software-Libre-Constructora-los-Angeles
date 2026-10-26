# Inventario de red y nombres (lo mantiene Integrante 1)

| Dato | Valor | Nota |
|---|---|---|
| Dominio de la zona | `losangeles.internal` | `.internal` (no `.local`), igual que en el curso |
| Sitio de la plataforma | `capacitacion.losangeles.internal` | alias `www` |
| IP del servidor (red interna) | `192.168.50.1` | si cambia en la integración, actualizar zona, DHCP y este archivo |
| IP del cliente Mint | DHCP 192.168.50.100–200 | DNS entregado por DHCP = 192.168.50.1 |
| Apache (servidor) | 80 → redirige a 443; 443 → proxy a 127.0.0.1:8081 | única entrada pública |
| Balanceador (Docker) | 127.0.0.1:8081 | solo local |
| Chamilo (réplicas) | sin puertos publicados | red interna de Compose |
| MariaDB | sin puertos publicados (3306 solo dentro de Compose) | |
| FTP | 21 + pasivo 40000–40100 | |
| Proyecto Compose / volúmenes | `chamilo` / `chamilo_datos_bd`, `chamilo_app`, `chamilo_sesiones` | |
| Carpeta de respaldos | `~/respaldos` | fuera de Docker y del repositorio |
