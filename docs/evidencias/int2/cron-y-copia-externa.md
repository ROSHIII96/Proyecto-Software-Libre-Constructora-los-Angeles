# Cron y copia externa de los respaldos (Integrante 2, servidor definitivo)

Fecha: 2026-11-02.

## Cron en el servidor
- Se reemplazo la linea del Lab 6 (`~/scripts/respaldar.sh`, respaldaba la MariaDB del host, ya deshabilitada) por la del proyecto; la vieja quedo comentada.
- Agenda real: `30 2 * * *` ejecuta `backups/respaldar.sh` todos los dias a las 02:30 (hora del servidor, Costa Rica).
- Prueba: se programo una ejecucion unica para las 17:00 y cron la lanzo (aparecio `OK BD` a las 17:00:07; el respaldo de archivos tarda ~10 minutos). Luego se quito la linea de prueba.
- Frecuencia: diaria, porque el curso cambia poco; el peor caso es perder hasta 24 horas (por ejemplo, las inscripciones o notas del dia). Convendria respaldar mas seguido en una capacitacion masiva.

## Copia externa (en la VM Mint, 192.168.50.101)
- Se eligio que **Mint jale** los respaldos del servidor (`rsync` por SSH) en vez de que el servidor los empuje: no hace falta servidor SSH en Mint, no hay clave en el servidor, y si el servidor se pierde o se compromete no puede borrar la copia externa.
- Clave `ed25519` sin frase de paso (cron no puede escribirla), guardada solo en Mint (`~/.ssh/respaldo_ed25519`); no va a Git.
- Prueba manual: `rsync` trajo los respaldos terminados (la base y los 352 MB de archivos) a `~/respaldos-losangeles/` en Mint, a ~5 MB/s. Excluye los `.tmp` a medio escribir y los respaldos viejos del Lab 6.
- Cron en Mint: `0 9 * * *` (09:00 UTC = 03:00 Costa Rica, despues de que termina el respaldo de las 02:30 + ~10 min). Mint esta en UTC.
- Limite honesto: la copia externa solo ocurre si Mint esta encendida a esa hora; si no, se jala a mano.
- Riesgo que cubre: perdida de la VM completa del servidor. Lo que NO cubre: perdida de Mint y del servidor a la vez.

## Actualización del 06/11/2026

Al revisar todo antes de la demo vimos dos cosas:

- El servidor estuvo apagado entre el 2 y el 6 de noviembre, así que no hubo respaldos nocturnos esos días (el último era del 02/11 a las 17:00). El cron solo funciona con la VM encendida a las 02:30. A las 13:09 lanzamos un respaldo manual y terminó bien a las 13:50 (tardó 41 minutos porque la VM estaba cargada; normalmente son unos 10).
- Mint había perdido la clave SSH, la carpeta de respaldos y el crontab. Lo rehicimos: clave nueva `respaldo_ed25519` sin frase de paso, autorizada en el servidor, y copia de prueba del respaldo de hoy (368 MB en 28 segundos). El cron de Mint quedó igual que antes: `0 9 * * *` en UTC, que son las 03:00 de Costa Rica.

Además, la línea de cron del servidor ahora usa `flock -n /tmp/respaldo.lock`, como dice `docs/decisiones.md`, y `backups/crontab.txt` quedó igual.
