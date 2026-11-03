# Integrante 5 — FTP, respaldos, documentación, costos y justificación de software libre

**Rama:** `int5-ftp-respaldos-docs` · **Evidencias:** `docs/evidencias/int5/` · **Respuestas:** `docs/guias/respuestas-int5.md`

## Objetivo

Tres entregas: (1) **FTP** con cuentas por integrante y aislamiento; (2) **respaldos automáticos con restauración demostrada** (Lab. #6 del profesor, Sesión 15); (3) **documentación final**: diagrama, manual, costos y justificación de software libre.

## Antes de empezar

- Todo el material está en el repositorio: `ftp/`, `backups/`, `docs/`. **Revise los scripts antes de ejecutarlos** y explique cada línea.
- Regla del profesor y del equipo: **ninguna contraseña en scripts ni en Git.** Las cuentas FTP se crean con `passwd` interactivo; la base se respalda tomando la contraseña de las variables del contenedor.
- Los respaldos necesitan la pila de pie (Integrantes 2 y 4). Mientras tanto haga los Bloques 1 y 5.

## Bloque 1 — Servidor FTP y cuentas (≈ 60 min)

**Qué va a hacer.** Instalar vsftpd (visto en clase) y crear una cuenta por integrante más una para el instructor del curso, cada una aislada.

```bash
sudo apt install vsftpd
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.original
# aplique las líneas de ftp/vsftpd-cambios.conf (compárelas una a una con su archivo)
sudo systemctl restart vsftpd
sudo systemctl status vsftpd
sudo bash ftp/crear-usuarios.sh        # pedirá cada contraseña con passwd
```

*Qué debe ver:* servicio `active (running)`, y las cuentas `ftp_int1`…`ftp_int5` y `ftp_instructor` con su carpeta en `/home`, permisos `700` y una subcarpeta `subida/`.

**Pruebas de aislamiento** (con `ftp` o `lftp` desde otro equipo/Mint):

```bash
ftp capacitacion.losangeles.internal    # usuario ftp_int2
ftp> pwd
ftp> cd /home/ftp_int3                  # debe FALLAR (permiso denegado o fuera de su jaula)
ftp> put prueba.txt                     # en subida/ funciona
```

*Qué debe ver:* cada cuenta entra solo a su carpeta; no puede leer la de otro; puede subir en `subida/`.

> **Punto de control 1 (sí/no):** capturas del estado de vsftpd, de las carpetas con permisos y de **un intento prohibido que falla** (eso es lo que demuestra el aislamiento).

**Pregunta de control:** ¿Por qué FTP simple es inseguro (viaja en texto plano) y qué alternativa usaría en producción? *(FTPS o SFTP; anótelo como mejora, no lo implemente si el profesor no lo pide.)*

## Bloque 2 — Scripts de respaldo (≈ 45 min)

Lea `backups/respaldar.sh` y compárelo con el del Lab. #6; prepare por escrito la diferencia:

| Tema | Lab. #6 del profesor | Nuestro proyecto |
|---|---|---|
| Base | `mysqldump` dentro del contenedor con `exec -T` | `mariadb-dump` con `exec -T`, contraseña tomada de las variables del contenedor |
| Archivos | no aplica | Chamilo guarda cursos y archivos subidos en el volumen `chamilo_app`: se respalda aparte con `tar` |
| Seguridad del archivo | — | escribe `.tmp` y hace `mv` al terminar (no queda un respaldo a medias) |
| Retención | — | borra respaldos con más de 7 días |

Pruebe a mano:

```bash
cd ~/proyecto-eif431o
bash backups/respaldar.sh
ls -lh ~/respaldos/                  # la carpeta de destino está FUERA de Docker y de Git
gunzip -t ~/respaldos/*.sql.gz       # integridad del respaldo
tar tzf ~/respaldos/*archivos*.tar.gz | head
```

*Qué debe ver:* un `.sql.gz` y un `.tar.gz` con fecha, tamaños razonables y sin errores en el log.

> **Punto de control 2 (sí/no):** captura de los respaldos generados, de la verificación de integridad y del log.

**Pregunta de control:** ¿Por qué se respalda también el volumen `chamilo_app` y no solo la base?

## Bloque 3 — Cron: automatización (≈ 30 min)

1. **Prueba rápida:** use la línea comentada de `backups/crontab.txt` que corre **cada minuto**; instálela con `crontab -e` y espere 3 minutos. Verifique que aparecen archivos nuevos y el log.
2. **Real:** comente la prueba y active `30 2 * * *` (todos los días 02:30). Confirme con `crontab -l`.
3. **Justifique la frecuencia** en `docs/respaldos.md`: el curso cambia poco → diario; ¿cuántos datos se pierden en el peor caso (hasta 24 h) y cuándo convendría respaldar más seguido (inscripciones masivas)?

> **Punto de control 3 (sí/no):** captura de `crontab -l`, de los archivos creados por la prueba y de la frecuencia justificada.

**Pregunta de control:** ¿Por qué el cron necesita `exec -T`? *(No hay terminal interactiva.)*

## Bloque 4 — Restauración demostrada (≈ 60 min) — **lo más importante**

Un respaldo que nunca se restauró no cuenta. Hágalo **con el Integrante 4**, y primero en una copia de prueba:

1. Anote conteos de `user` y `course` y los archivos de un curso.
2. Respalde (Bloque 2). Cree después un usuario "posterior".
3. Simule el desastre: `docker compose down -v` **(solo en el entorno de prueba o con acuerdo explícito del grupo).**
4. `docker compose up -d bd`, luego `bash backups/restaurar.sh <respaldo-bd>` y `bash backups/restaurar-archivos.sh <respaldo-archivos>`; `docker compose up -d`.
5. Entre a Chamilo: usuarios y cursos presentes, el usuario "posterior" **ausente**, los conteos coinciden con el paso 1.
6. Mida el tiempo total.

> **Punto de control 4 (sí/no):** capturas del antes, del desastre, de la restauración y de los conteos; tiempo medido. Sin esto el respaldo no se considera probado.

**Pregunta de control:** ¿Qué diferencia hay entre "tengo respaldo" y "puedo restaurar"? ¿Qué se perdió y por qué?

## Bloque 5 — Copia fuera del servidor (≈ 40 min)

Si la VM muere, los respaldos que están dentro de ella mueren también. Copie fuera:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/respaldo_ed25519        # con frase de paso; la clave NO va a Git
ssh-copy-id -i ~/.ssh/respaldo_ed25519.pub usuario@equipo-destino
rsync -av -e "ssh -i ~/.ssh/respaldo_ed25519" ~/respaldos/ usuario@equipo-destino:~/respaldos-losangeles/
```

El destino puede ser la VM Mint u otra máquina del grupo. Agregue el `rsync` al cron (después del respaldo) y verifique que llegan los archivos.

> **Punto de control 5 (sí/no):** captura de los archivos en el destino. Esta copia es la base del simulacro de recuperación del Integrante 3 (Bloque 7).

**Pregunta de control:** ¿Qué riesgo cubre la copia externa que no cubre el cron local?

## Bloque 6 — Documentación final (≈ 3 h, repartidas hasta el viernes 06/11)

Consolide con las notas de todos, en `README.md` y `docs/`:

1. **Diagrama de arquitectura** (con el Integrante 1): cliente → DNS → Apache HTTPS → nginx → 2 réplicas Chamilo → MariaDB; volúmenes; FTP; respaldos. Marque los **puntos únicos de fallo** (Apache, la base, la VM).
2. **Manual de instalación paso a paso** para repetir todo desde cero, con versiones exactas (`docs/versiones.md`).
3. **Inventario de red** (`docs/inventario-red.md`) y decisiones (`docs/decisiones.md`), incluidos los cambios sobre el diseño inicial y por qué (sin Galera/Gluster: razón y límites).
4. **Pruebas realizadas** con evidencias, incluidas las que no salieron perfectas.
5. **Limitaciones honestas:** la caída de una réplica es automática; la caída de la VM completa requiere recuperación manual desde la copia externa.

> **Punto de control 6 (sí/no):** README actualizado, diagrama exportado y manual probado por **otra persona** del equipo siguiéndolo desde cero.

## Bloque 7 — Justificación de software libre (≈ 90 min)

Para cada componente indique licencia, qué reemplaza o hace, y por qué conviene. **Verifique cada licencia en el sitio oficial antes de escribirla** y anote la fuente:

| Componente | Licencia (verificar) | Función |
|---|---|---|
| Chamilo LMS | GPL v3 | Plataforma de capacitación |
| MariaDB | GPL v2 | Base de datos |
| Apache HTTP Server | Apache 2.0 | Proxy HTTPS |
| nginx | BSD de 2 cláusulas | Balanceo entre réplicas |
| BIND9 | MPL 2.0 | DNS |
| vsftpd | GPL v2 | FTP |
| Docker Engine | Apache 2.0 | Contenedores |
| Linux (Mint / servidor) | GPL y otras | Sistema operativo |

Argumentos a desarrollar con ejemplos del proyecto: sin pago de licencias por usuario; código auditable; independencia de un solo proveedor; adaptable al caso (personalización de Chamilo); comunidad. Alternativa libre considerada: Moodle (explique por qué se eligió la plataforma asignada y qué ofrecería la otra).

> **Punto de control 7 (sí/no):** `docs/software-libre.md` con la tabla verificada y fuentes enlazadas.

## Bloque 8 — Comparación de costos (≈ 90 min)

El escenario compara capacitar **con este servidor libre** frente a una **charla presencial sin registro** (o una plataforma propietaria). **No invente cifras.** Construya la tabla con supuestos explícitos y cotizaciones reales que usted mismo consulte:

| Concepto | Opción libre (este proyecto) | Alternativa (charla / plataforma comercial) | Fuente |
|---|---|---|---|
| Licencias | $0 | cotización real | enlace |
| Hardware / nube | VM (costo real o equipo existente) | — | cotización |
| Implementación inicial | horas del equipo × tarifa supuesta | — | supuesto declarado |
| Operación mensual | mantenimiento, electricidad/nube | — | |
| Costo por trabajador capacitado | | | cálculo |
| Costo de **no** capacitar (accidente, multas) | no cuantificar sin dato real; describir | | |

Reglas: separe costo **inicial** de **recurrente**; declare cada supuesto (p. ej. salario de referencia con fuente oficial como el MTSS); si no consigue un dato, escriba "pendiente de cotización", **no un número inventado**.

> **Punto de control 8 (sí/no):** `docs/costos.md` con fuentes o con "pendiente" donde corresponda, y fórmulas visibles.

**Pregunta de control:** ¿Qué parte del ahorro es cierta y qué parte es supuesto? ¿Cómo lo dice en la exposición sin exagerar?

## Entregables en el repositorio (PR)

`ftp/` y `backups/` ajustados, `docs/respaldos.md`, `docs/software-libre.md`, `docs/costos.md`, `README.md`, diagrama, manual, evidencias.

## Si algo falla

- **FTP: `530 Login incorrect`:** contraseña, o `/etc/vsftpd.conf` sin `local_enable=YES`; `sudo journalctl -u vsftpd`.
- **FTP: `500 OOPS: vsftpd: refusing to run with writable root inside chroot`:** la jaula no puede ser escribible; suba solo a `subida/`.
- **Un usuario ve carpetas de otro:** revise `chroot_local_user` y los permisos `700`.
- **`respaldar.sh`: `service "bd" is not running`:** ejecute desde `docker/` o con `-f` apuntando al compose; `docker compose ps`.
- **Cron no corre:** rutas absolutas en el script, `crontab -l`, `grep CRON /var/log/syslog`.
- **El respaldo pesa 0 bytes:** falló el volcado; revise el log (el `.tmp` no se mueve si falló).
- **`rsync` pide contraseña:** la clave no está copiada o no se usa `-i`; compruebe con `ssh -i … usuario@destino`.
