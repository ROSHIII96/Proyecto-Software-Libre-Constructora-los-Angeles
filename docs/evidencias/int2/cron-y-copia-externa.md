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
