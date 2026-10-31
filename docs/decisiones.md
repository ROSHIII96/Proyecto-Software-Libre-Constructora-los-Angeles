# Registro de decisiones del proyecto

| Fecha | Decisión | Alternativas consideradas | Motivo | Responsable |
|---|---|---|---|---|
| 25/10/2026 | Utilizar Nginx en el servidor como proxy HTTPS | Apache del laboratorio | Se decidió utilizar Nginx como punto de entrada del proyecto y mantener un único certificado HTTPS en el servidor | Integrante 1 / Equipo |
| 25/10/2026 | Utilizar BIND9 para el DNS interno | Archivo hosts manual | Permite que los clientes resuelvan `capacitacion.losangeles.internal` dentro de la red de pruebas | Integrante 1 |
| 25/10/2026 | Utilizar nginx dentro de Docker como balanceador | HAProxy | Ya forma parte de la arquitectura del proyecto y permite distribuir tráfico entre las réplicas de Chamilo | Integrante 3 |
| 25/10/2026 | Utilizar una sola instancia MariaDB con volumen persistente | Galera / replicación de base de datos | La replicación de base de datos se dejó como una etapa opcional. Se priorizó una arquitectura más simple respaldada por copias periódicas | Integrante 4 / Equipo |
| 30/10/2026 | Utilizar Chamilo 1.11.40 con PHP 8.3 y MariaDB 11.8 | PHP 7.4 y MariaDB 10.11 como planes alternativos | La plataforma pudo instalarse y funcionar correctamente con las versiones seleccionadas durante las pruebas realizadas | Integrantes 2 y 4 |
| 30/10/2026 | Guardar los respaldos fuera de Docker | Guardarlos dentro de un volumen o contenedor | Permite conservar los respaldos aunque los contenedores o volúmenes del proyecto sean eliminados | Integrante 5 |
| 30/10/2026 | Realizar respaldos automáticos diariamente a las 02:30 | Frecuencias más cortas | La plataforma no tendrá cambios constantes durante todo el día y un respaldo diario limita la pérdida máxima aproximada a 24 horas | Integrante 5 |
| 31/10/2026 | Utilizar `flock` en la tarea de respaldo | Ejecutar directamente desde Cron | Durante la prueba cada minuto se generaron ejecuciones superpuestas. `flock` evita que dos respaldos se ejecuten simultáneamente | Integrante 5 |
| 31/10/2026 | Mantener una copia externa de los respaldos en Linux Mint | Solo respaldos locales | Si se pierde completamente la VM principal, los respaldos externos permiten recuperar la plataforma | Integrante 5 |
| 31/10/2026 | Automatizar la copia externa a las 03:00 mediante rsync y SSH | Copia manual | Evita depender de una copia manual y permite transferir automáticamente el respaldo generado a las 02:30 | Integrante 5 |
| 31/10/2026 | Crear una clave SSH independiente sin frase de paso para Cron | Utilizar la clave personal con frase de paso | Las tareas Cron no pueden introducir de forma interactiva una frase de paso; se creó una clave dedicada únicamente a la copia automática de respaldos | Integrante 5 |
| 31/10/2026 | Utilizar FTP simple únicamente para fines académicos | SFTP / FTPS | vsftpd forma parte de los requerimientos y prácticas del curso. Para producción se recomienda utilizar un protocolo cifrado | Integrante 5 |
| 31/10/2026 | Mantener el balanceador publicado únicamente en `127.0.0.1:8081` | Publicarlo en `0.0.0.0:8081` | Reduce la exposición directa del balanceador; Nginx del servidor debe ser el punto de entrada hacia la plataforma | Equipo |

## Decisiones sobre recuperación

Se comprobó una restauración completa utilizando un respaldo de la base de datos y otro de los archivos persistentes de Chamilo.

Para validar el momento exacto del respaldo se utilizaron dos usuarios:

- `respaldo_a`: creado antes de generar el respaldo.
- `respaldo_b`: creado después de generar el respaldo.

Después de eliminar los datos persistentes y restaurar el respaldo:

- `respaldo_a` volvió a existir;
- `respaldo_b` no apareció;
- la base recuperó 239 tablas;
- Chamilo volvió a estado saludable;
- el servicio respondió HTTP 200.

Esta prueba confirmó que el procedimiento de respaldo permite regresar al estado existente en el momento en que se creó la copia.

## Limitaciones aceptadas

La arquitectura actual tiene los siguientes puntos únicos de fallo:

- Nginx del servidor;
- MariaDB;
- la máquina virtual principal.

Las réplicas de Chamilo permiten continuar atendiendo solicitudes si una instancia de la aplicación falla.

La pérdida completa de la VM requiere una recuperación manual utilizando los respaldos externos.
