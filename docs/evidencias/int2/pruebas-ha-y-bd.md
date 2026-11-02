# Pruebas de alta disponibilidad y base de datos (Integrante 2, servidor definitivo)

Fecha: 2026-11-02. Servidor: el definitivo (192.168.50.1). Todo lo de abajo salio de comandos reales; los logs crudos estan en esta carpeta.

## Una replica cae (`docker stop chamilo-chamilo-1`)
- Log: `ha-parada-una-replica.txt`. Dos peticiones se reintentaron en la otra replica (la coma en la columna del servidor) y ambas terminaron en **200**; la mas lenta tardo unos 3 s. Ningun error visible.
- El stop tardo 1,5 s. Al arrancar de nuevo, la replica volvio a recibir trafico a los ~7 s.

## Caen las dos replicas (`docker stop` de ambas)
- Log: `ha-parada-ambas-replicas.txt` (tramo valido: 16:12:08 a 16:12:40).
- Detenidas a las 16:12:16: respuestas **502** y un **504**, hasta el arranque. Arrancadas a las 16:12:28, primer **200** a las 16:12:31 (3 s).
- Limite honesto: con una replica la caida no se nota; con las dos hay interrupcion hasta que se levantan.
- Nota: despues de las 16:12:40 el reloj de la VM salta (3 min); se descarta ese tramo. En una primera prueba hubo otro hueco de 23 s. Parecen pausas de la maquina virtual, no fallos de Chamilo; esa primera prueba no se usa como evidencia.

## Cae la base de datos
- Antes: 6 usuarios y 1 curso.
- `docker kill chamilo-bd-1`: el contenedor quedo `Exited (137)` y **no** se reinicio solo, aunque la politica es `unless-stopped`. Se arranco a mano; el log muestra `Starting table crash recovery...` y `ready for connections` a los 4 s. Despues: 6 usuarios y 1 curso (datos intactos).
- `kill -9` del proceso de mariadbd desde el host (caida real): **reinicio automatico** (RestartCount=1), `healthy` a los 20 s, 6 usuarios y 1 curso.
- Conclusion: una caida real del proceso se recupera sola en unos 20 s sin perder lo confirmado; `docker kill` no sirve para probar el reinicio automatico en esta version de Docker.

## Permisos minimos
- `chamilo_user` tiene `GRANT ALL PRIVILEGES ON chamilo.*` y ve solo `chamilo` e `information_schema`.
- El contenedor `bd` no publica puertos (`3306/tcp` sin mapeo; `docker compose port` sin resultado).
- Hallazgo: habia una MariaDB 11.8.6 del sistema (instalada con apt, de un laboratorio previo) escuchando en 192.168.50.1:3306. Se detuvo y deshabilito (`systemctl disable --now mariadb`); no se borraron sus datos. Ahora no escucha nada en el 3306 del host.
- Nota: existe `root@%` (valor por defecto de la imagen); solo es alcanzable desde la red interna de Docker. La salida de `SHOW GRANTS` incluye el hash de la contrasena: no se sube sin tapar.
