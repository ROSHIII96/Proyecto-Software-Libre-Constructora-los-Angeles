# Documento técnico — Capacitación sin registro para Constructora Los Ángeles

**Curso:** EIF431O Administración de Servidores basados en Software Libre
**Equipo:** Kernel Panic (Dixon, Diego, Joseth, Ivan, Derek)
**Escenario 2:** Chamilo LMS para la capacitación de los trabajadores
**Servidor de la demo:** `serverdiego` (Ubuntu Server, 192.168.50.1)

Este documento junta en un solo lugar cómo está montada la plataforma, por qué se tomaron las decisiones, cómo se reproduce desde cero y qué evidencia respalda cada afirmación. Los detalles paso a paso de cada parte están en los documentos de `docs/` que se citan en cada sección.

---

## 1. El problema y lo que se entrega

La constructora capacita a sus trabajadores (seguridad en obra, por ejemplo) sin dejar registro: no se sabe quién hizo qué capacitación ni con qué resultado. La solución es una plataforma Chamilo donde un instructor publica el curso y los trabajadores lo completan, con resultados guardados y consultables.

Lo que quedó funcionando:

- Chamilo 1.11.40 con el curso **Seguridad en obra** (`SEGOBRA`): lección de 3 pasos, un PDF y una evaluación de 5 preguntas.
- Un instructor (Carlos Ramírez) y tres estudiantes de ejemplo, con progreso y notas visibles en los informes.
- Acceso por nombre (`https://capacitacion.losangeles.internal`) con HTTPS.
- Dos réplicas de la aplicación detrás de un balanceador, con una sola base de datos.
- Respaldos diarios automáticos, copia en otra máquina y restauración probada.
- FTP con una cuenta aislada por integrante.

## 2. Arquitectura

```
Mint (cliente, 192.168.50.101)
   │  DNS
   ▼
BIND9 (192.168.50.1)  zona losangeles.internal
   │  HTTPS
   ▼
Nginx del servidor   80 → redirige a 443 · certificado autofirmado
   │  127.0.0.1:8081 (solo local)
   ▼
Balanceador nginx (Docker)
   ├──► chamilo-1  (php:8.3-apache)
   └──► chamilo-2  (php:8.3-apache)
              │
              ▼
        bd  (mariadb:11.8)   sin puertos publicados
```

| Componente | Función | Versión / licencia |
|---|---|---|
| Chamilo LMS | Plataforma de cursos y evaluaciones | 1.11.40 · GPLv3+ |
| PHP + Apache | Ejecutan Chamilo dentro del contenedor | PHP 8.3 |
| MariaDB | Base de datos | 11.8 · GPLv2 |
| Nginx (servidor) | Punto de entrada HTTPS | BSD-2 |
| Nginx (Docker) | Balanceador entre réplicas | 1.30-alpine · BSD-2 |
| BIND9 | DNS interno | MPL 2.0 |
| vsftpd | Servicio FTP | GPL |
| Docker Engine + Compose | Contenedores | Apache 2.0 |
| Ubuntu / Linux | Sistema operativo | GPLv2 (kernel) |

Datos de red (direcciones, puertos, volúmenes): `docs/inventario-red.md`. Versiones exactas verificadas en el servidor: `docs/versiones.md`.

**Persistencia.** Tres volúmenes con nombre fijo: `chamilo_datos_bd` (la base), `chamilo_app` (código, cursos, archivos subidos, tema y logo) y `chamilo_sesiones` (sesiones PHP compartidas entre réplicas, para que un usuario no pierda la sesión si lo atiende la otra réplica). `docker compose down` los conserva; `down -v` los borra y no debe usarse en el servidor definitivo.

**Exposición de red.** Hacia la red solo salen 80/443 (Nginx), 53 (DNS), 21 y 40000-40100 (FTP) y 22 (SSH). El balanceador escucha solo en `127.0.0.1:8081`, Chamilo no publica su puerto y MariaDB no publica el 3306. Se comprobó que `docker compose port bd 3306` no devuelve nada.

## 3. Decisiones y compromisos (trade-offs)

El registro completo con fechas y responsables está en `docs/decisiones.md`. Las más importantes y lo que costó cada una:

| Decisión | Alternativa | Por qué | Lo que se cede |
|---|---|---|---|
| Todo en Docker Compose | Instalar Chamilo directo en el sistema | La misma imagen se reproduce en cualquier servidor y las réplicas son una línea (`--scale chamilo=2`) | Hay que entender volúmenes: un `down -v` borra los datos |
| Una sola MariaDB con volumen | Galera / replicación | Más simple de operar y de explicar; los respaldos cubren la pérdida de datos | La base es un punto único de fallo |
| Dos réplicas de Chamilo + balanceador nginx | Una sola instancia / HAProxy | Si una réplica cae, el usuario no lo nota; nginx ya estaba en el proyecto | Si caen las dos, hay corte; el Nginx del servidor y la base siguen siendo puntos únicos |
| Balanceador que consulta el DNS de Docker cada 5 s | Nombres fijos de contenedor | Una réplica detenida deja de recibir tráfico y una nueva entra sin recargar nginx | Dependencia del resolver interno de Docker |
| Sesiones PHP en volumen compartido | Sesiones en cada réplica | Evita cerrar la sesión del usuario al cambiar de réplica | Un volumen más que respaldar/cuidar |
| `/salud` como healthcheck | Solo probar el puerto | Detecta una aplicación viva pero con error | — |
| HTTPS con certificado autofirmado | Certificado de una autoridad pública | El dominio `.internal` no se puede validar públicamente; sirve para la red de pruebas | El navegador avisa; en producción se usaría una CA interna |
| Respaldos fuera de Docker (`~/respaldos`) | Dentro de un volumen | Sobreviven si se borran contenedores o volúmenes | Hay que cuidarlos como cualquier carpeta del servidor |
| Copia externa que **jala Mint** con rsync/SSH | Que el servidor empuje | No hay clave del destino en el servidor; un servidor comprometido no borra la copia | Solo funciona si Mint está encendida a esa hora |
| `flock` en el cron | Cron directo | En una prueba se solaparon respaldos; el candado lo evita | — |
| FTP simple (vsftpd) | SFTP/FTPS | Lo pide el curso | No cifra; en producción se usaría SFTP |
| Detener la MariaDB del sistema | Dejarla | Era un resto de un laboratorio y exponía el 3306 en la red | — |
| Probar restauración en copia aislada | Restaurar sobre el servidor definitivo | Los scripts usan el volumen `chamilo_app`; un fallo destruiría la instalación | Prueba algo más larga de montar |

## 4. Reproducción desde cero

Resumen; el procedimiento con cada comando está en `docs/manual-int2-servidor-definitivo.md` (servidor definitivo) e `docs/instalacion.md`.

1. **Servidor:** Ubuntu Server con Docker Engine, Docker Compose, Git, Nginx, BIND9, vsftpd y OpenSSH.
2. **Código:** `git clone` del repositorio en `~/proyecto-eif431o`.
3. **Variables:** en `docker/`, copiar `.env.example` a `.env`, completar las claves y `chmod 600 .env`. El `.env` nunca se sube a Git.
4. **DNS:** copiar la zona de `dns/` a `/etc/bind/`, validar con `named-checkconf` y `named-checkzone`, reiniciar `bind9`. Probar con `dig capacitacion.losangeles.internal`.
5. **HTTPS:** generar el certificado autofirmado en `/etc/ssl/losangeles/`, colocar `nginx/capacitacion.conf` en Nginx (80 → 443, proxy a `127.0.0.1:8081`, `client_max_body_size 100m`), `nginx -t` y recargar.
6. **Contenedores:** en `docker/`, `docker compose up -d --build`; esperar a `healthy` en `bd` y `chamilo`.
7. **Instalar Chamilo** desde el navegador **por el dominio, no por la IP** (host de BD `bd`, base `chamilo`, usuario `chamilo_user`; la URL del portal debe ser `https://capacitacion.losangeles.internal/`).
8. **Réplicas:** `docker compose up -d --scale chamilo=2`.
9. **Contenido:** crear el curso `SEGOBRA`, lección, PDF, ejercicio y cuentas (instructor y estudiantes).
10. **Marca:** aplicar tema y logo de `docker/personalizacion/` (pasos en su README).
11. **FTP:** `/etc/vsftpd.conf` desde `ftp/vsftpd.conf` y `sudo bash ftp/crear-usuarios.sh`.
12. **Respaldos:** `backups/respaldar.sh` y el cron de `backups/crontab.txt`; en Mint, la clave SSH y el cron de la copia externa (`docs/respaldos.md`).

> Nota para quien siga `docs/instalacion.md`: en la sección FTP y en la de cron/copia externa describe un modelo anterior (cuentas `ftp_int1…`, copia que el servidor empuja a Mint). El sistema que corre es el descrito aquí y en el manual del Int2: cuentas por integrante, y copia que jala Mint. Esas secciones deben alinearse antes de entregar.

## 5. Alta disponibilidad: qué se probó

Con `docker/probar-ha.sh` (una petición por segundo mostrando código HTTP y réplica que respondió):

- **Cae una réplica:** el usuario no ve nada. Dos peticiones se reintentaron en la otra réplica y dieron 200; la más lenta tardó unos 3 s. La réplica volvió a recibir tráfico unos 7 s después de arrancar.
- **Caen las dos:** 502/504 hasta que arrancan; primer 200 a los 3 s de arrancar.
- **Cae la base:** `docker kill` dejó el contenedor detenido (no se reinició; no se verificó el motivo). Con un `kill -9` real del proceso `mariadbd`, Docker lo reinició solo (`RestartCount=1`), quedó `healthy` a los 20 s y los datos estaban intactos.

Limitación aceptada: la alta disponibilidad cubre la aplicación, no al Nginx del servidor, a la base ni a la máquina virtual.

## 6. Respaldos y recuperación

- `backups/respaldar.sh` genera un `.sql.gz` de la base (~51 KB) y un `.tar.gz` de los archivos de Chamilo (~350 MB) en `~/respaldos`, escribe primero un `.tmp` y lo renombra al terminar, y borra lo de más de 7 días.
- Cron en el servidor a las 02:30 con `flock` (solo corre si la VM está encendida).
- Cron en Mint a las 09:00 UTC (03:00 Costa Rica): `rsync` por SSH con una llave dedicada, sin frase de paso, que jala los respaldos a `~/respaldos-losangeles/`.
- **Restauración probada** en una copia aislada (proyecto `prueba`, volúmenes `prueba_*`, puerto 8082): base en 83 s y archivos en 114 s. Se usaron dos usuarios marcadores: el creado antes del respaldo volvió y el creado después no, con 239 tablas recuperadas y HTTP 200.
- Pérdida máxima aceptada: un día de cambios.

Procedimientos: `docs/respaldos.md`, `backups/instrucciones-respaldos-restauracion.md`.

## 7. Monitoreo y seguridad

Plan de monitoreo (espacio, logs, puertos): `docs/monitoreo-bd.md`. Medidas aplicadas:

- Contenedor de la base sin puertos publicados; `chamilo_user` limitado a la base `chamilo` (no es root).
- Balanceador solo en `127.0.0.1`.
- Cookie de sesión con `HttpOnly` (verificado en `ch_sid`).
- Usuarios FTP aislados en su carpeta: entrar a la de otro devuelve `550 Failed to change directory`; sin acceso anónimo.
- Secretos fuera del repositorio.

Puntos débiles conocidos: FTP sin cifrar, certificado autofirmado, claves de la copia externa sin frase de paso (por requerir automatización).

## 8. Software libre: justificación y comparación

Todos los componentes son software libre con licencia aprobada por OSI (tabla de la sección 2). Fuentes oficiales de cada licencia: `docs/software-libre.md`.

### 8.1 Chamilo frente a alternativas

El enunciado asigna Chamilo; aun así se compararon criterios técnicos y de costo con Moodle (también libre) y con un LMS propietario de suscripción (descrito de forma genérica, sin cotización real).

| Criterio | Chamilo 1.11 | Moodle | LMS propietario (SaaS) |
|---|---|---|---|
| Licencia | GPLv3+ | GPLv3+ | Propietaria |
| Costo de licencia | ₡0 | ₡0 | Pago recurrente, normalmente por usuario |
| Funciones para este caso (cursos, lecciones, ejercicios, informes) | Cubre lo necesario | Cubre lo necesario y mucho más | Cubre lo necesario |
| Complejidad de instalación y operación | Menor: una aplicación PHP y una base | Mayor: más módulos y ajustes | Ninguna (lo opera el proveedor) |
| Control de los datos | Total, en el servidor propio | Total | Datos en el proveedor |
| Dependencia del proveedor | Ninguna | Ninguna | Alta |
| Escalado | Réplicas + sesiones compartidas (probado) | Igual de posible | Lo resuelve el proveedor |
| Costo operativo | Horas técnicas + hardware + electricidad | Similar o algo mayor por complejidad | Incluido en la suscripción |

Conclusión: para una constructora que necesita capacitación sencilla con registro de resultados, Chamilo cubre el requisito con menos operación que Moodle y sin la dependencia ni el pago recurrente de un servicio propietario. Moodle sería razonable si la empresa necesitara funciones avanzadas (extensiones, analítica, grandes volúmenes).

### 8.2 Otras elecciones de software

- **Nginx frente a Apache** como entrada: configuración corta para proxy inverso y balanceo, y el mismo programa sirve de balanceador interno.
- **BIND9 frente a archivo `hosts`:** un `hosts` obliga a editar cada cliente; BIND9 resuelve el nombre para toda la red.
- **MariaDB frente a MySQL:** compatible con Chamilo, licencia GPL sin edición comercial de por medio.
- **Docker frente a instalación nativa:** reproducibilidad y réplicas sencillas.

## 9. Costos

Supuestos explícitos: el prototipo reutilizó equipos existentes (hardware adicional ₡0) y la red interna de la empresa (Internet adicional ₡0). Los montos que dependen de cotizaciones reales se calculan con fórmula; el detalle completo está en `docs/costos.md`.

| Rubro | Cómo se calcula | Monto |
|---|---|---|
| Licencias (Chamilo, MariaDB, Nginx, BIND9, vsftpd, Docker, Linux) | Sin licencia | ₡0 |
| Hardware | Precio del servidor + almacenamiento + equipo de respaldo, o ₡0 si se reutiliza | Por cotizar / ₡0 reutilizando |
| Implementación | Horas × tarifa técnica | Por definir con tarifa real |
| Electricidad | kW × horas × días × tarifa. Ejemplo: 0,15 kW × 24 h × 30 días = 108 kWh/mes, a la tarifa vigente de la distribuidora | Variable |
| Mantenimiento | Horas mensuales × tarifa (p. ej. 4 h/mes) | Variable |
| Almacenamiento de respaldos | Cada día se guardan ~350 MB, con retención de 7 días (~2,5 GB) más la copia externa | Variable según disco |

**Frente a la capacitación presencial:** costo presencial = instructor + tiempo de los trabajadores + transporte + materiales + espacio + repeticiones para ausentes + registro manual. La plataforma convierte el curso en un recurso reutilizable: la misma capacitación se repite sin volver a pagar sesiones, y los resultados quedan registrados. Los valores definitivos necesitan datos reales de la empresa y cotizaciones; hasta entonces las cifras que dependen de ellos se dejan como fórmula, no como número inventado.

## 10. Problemas reales que se resolvieron

| Qué pasó | Causa | Solución |
|---|---|---|
| El instalador proponía una URL con `:80` | Se instaló sin pasar por el dominio | Cambiar la URL del portal a `https://capacitacion.losangeles.internal/` |
| Había una MariaDB en `192.168.50.1:3306` | Resto de un laboratorio anterior | `systemctl disable --now mariadb` (sin borrar datos) |
| Nginx rechazaba archivos grandes | Límite por defecto de 1 MB | `client_max_body_size 100m`, igual que PHP |
| `docker kill` no reinició la base | No verificado | Probar con `kill -9` real del proceso |
| Pausas de 23 s y 3 min en la VM durante HA | La VM se detiene | Descartar esos tramos; no suspender el equipo en la demo |
| Respaldos solapados cada minuto en una prueba | Cron sin candado | `flock -n` |
| Los scripts de restauración pisarían el servidor | Volumen `chamilo_app` con nombre fijo | Restaurar solo en copia aislada |
| Sin respaldos nocturnos del 3 al 6 de noviembre | Servidor apagado a las 02:30 | Respaldo manual y documentado; la VM debe estar encendida de noche |
| Mint perdió llave, carpeta y crontab | Probable estado anterior de la VM | Rehacer la copia externa y documentarla |
| "Media del ejercicio 0 %" en el resumen del profesor | No investigado | En la demo se usa el informe de Ejercicios, que coincide con la nota |

## 11. Índice de evidencias

| Qué se demuestra | Dónde está |
|---|---|
| Prueba de humo 9/9 y capturas | `docs/evidencias/int2/`, `docs/Respuestas/respuestas-int2.md` |
| Alta disponibilidad (logs de `probar-ha.sh`) | `docs/evidencias/int2/` |
| MariaDB: permisos, puertos, 239 tablas, monitoreo | `docs/evidencias/int4/`, `docs/Respuestas/respuestas-int4.md`, `docs/monitoreo-bd.md` |
| Respaldos, cron, copia externa, restauración | `docs/evidencias/int5/`, `docs/respaldos.md`, `backups/instrucciones-respaldos-restauracion.md` |
| FTP y aislamiento | `ftp/instrucciones-ftp.md`, `docs/Respuestas/respuestas-int5.md` |
| DNS y HTTPS (Int1) | `docs/Respuestas/Respuestas-Int-1.md` |
| Réplicas y balanceador (Int3) | `docs/Respuestas/respuestas-int3.md`, `docs/evidencias/int 3/` |
| Contenido del curso (lecciones, segundo parcial, PDF) | `contenido-curso/` |
| Decisiones | `docs/decisiones.md` |
| Versiones | `docs/versiones.md` |
| Estado del servidor con fecha y huellas SHA-256 | `evidencias/estado-servidor.txt`, `hashes.txt` (carpeta de entrega) |

## 12. Límites y mejoras

- Puntos únicos de fallo: Nginx del servidor, MariaDB y la VM.
- Respaldo diario: se puede perder hasta un día de cambios.
- FTP sin cifrar y certificado autofirmado.
- Mejoras razonables: replicación de la base, SFTP, certificado de una CA interna, monitoreo con alertas, ejecutar el respaldo con un temporizador del sistema en vez de depender de que la VM esté encendida.
