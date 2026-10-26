# Registro de decisiones (una entrada por decisión que afecte a más de un integrante)

| Fecha | Decisión | Alternativas consideradas | Motivo | Quién |
|---|---|---|---|---|
| 25/10 | Apache en el servidor como proxy HTTPS delante de Docker | HTTPS dentro del contenedor; HAProxy | Es el método del Lab. #5 del curso; un solo certificado; el contenedor queda sin exponer | Int. 1 |
| 25/10 | Balanceador nginx + `--scale chamilo=2` | HAProxy + keepalived | Patrón del repositorio del profesor (`compose_loadbalancer`); menos piezas | Int. 3 |
| 25/10 | Una sola MariaDB con volumen y respaldos | Galera / replicación | Lo que enseña el curso; la replicación se evalúa como etapa 3 | Int. 4 |
