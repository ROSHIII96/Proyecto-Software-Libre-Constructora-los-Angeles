# Integrante 3 — Segunda réplica, balanceo, alta disponibilidad y evaluación del curso

**Rama:** `int3-alta-disponibilidad` · **Evidencias:** `docs/evidencias/int3/` · **Respuestas:** `docs/guias/respuestas-int3.md`

## Objetivo

Cumplir el **bonus** del proyecto: dos instancias del mismo servicio sirviendo el mismo sitio, con la **demostración de que si una cae, la otra responde**; y comprobar qué pasa con los datos cuando algo falla. Además, completar con el Integrante 2 la parte del curso en Chamilo: evaluación, usuarios y reporte del Instructor.

Lo que enseñó el profesor es el patrón de `cachac/dockerlabs` (`compose_loadbalancer`, capítulos 06 y 11): contenedores idénticos con `--scale` detrás de un nginx. Su propio capítulo 06 advierte: *"el balanceador no está realizando un health check, por lo que intenta enviar tráfico aunque estén caídos"*. **Nuestro balanceador corrige justo eso** (ver bloque 3), y es lo que usted debe saber explicar.

## Antes de empezar

- Mientras el Integrante 2 termina la instalación (martes 27/10), trabaje el **Bloque 1** con el repositorio del profesor en su VM: no depende de nadie.
- Desde el Bloque 2 necesita la pila del Integrante 2 funcionando y Chamilo **ya instalado** (rama `int2-chamilo-imagen`).
- Nunca haga `docker compose down -v` en la pila del proyecto: borra la plataforma.

## Bloque 1 — Calentamiento con el laboratorio del profesor (≈ 40 min)

**Qué va a hacer y por qué.** Entender el problema antes de resolverlo: repetir el balanceo del Lab. #11 (§9) y el capítulo 06 (§4.5), y ver con sus ojos qué falla.

```bash
git clone https://github.com/cachac/dockerlabs && cd dockerlabs
docker compose -f compose_loadbalancer/docker-compose.yml up -d --scale multidocker=3
docker compose -f compose_loadbalancer/docker-compose.yml ps
docker compose -f compose_loadbalancer/docker-compose.yml logs loadbalancer
```

*Qué debe ver:* con Compose v2 los contenedores se llaman con **guion** (`…-multidocker-1`), pero `nginx-loadbalancer.conf` trae nombres con **guion bajo** (`…_multidocker_1`): el log dice `host not found in upstream`. Es el error que el propio Lab. #11 pide "validar y reparar" (§9.10). Repárelo con los nombres reales (`docker ps`), reinicie el balanceador, y luego **detenga un contenedor** de la app (`docker stop …`) y genere tráfico desde el navegador. Observe: nginx sigue enviando peticiones al contenedor caído (errores/lentitud), porque la lista de servidores es **fija** y no se verifica.

Limpie al terminar: `docker compose -f compose_loadbalancer/docker-compose.yml down`.

> **Punto de control 1 (sí/no):** captura del `host not found in upstream`, de la corrección y del comportamiento con un contenedor detenido.

**Pregunta de control:** ¿Por qué falla ese balanceador cuando un contenedor cae, y qué dos cosas están "fijas" en su configuración?

## Bloque 2 — La segunda réplica sobre la pila del proyecto (≈ 20 min)

**Qué va a hacer y por qué.** `chamilo` es **un servicio** que se multiplica con `--scale` (igual que `multidocker` del Lab. #11). Las dos réplicas usan **la misma imagen** y los **mismos volúmenes**: `chamilo_app` (código, configuración, cursos y archivos subidos) y `chamilo_sesiones` (sesiones PHP). Por eso la segunda réplica ve exactamente lo mismo que la primera.

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d --scale chamilo=2
docker compose ps
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

*Qué debe ver:* dos contenedores de `chamilo` (algo como `chamilo-chamilo-1` y `chamilo-chamilo-2`), ambos `(healthy)`. **Anote los nombres reales:** los necesitará para detener cada uno.

Compruebe que **comparten** archivos y sesiones:

```bash
docker exec chamilo-chamilo-1 touch /var/www/html/prueba-ha.txt
docker exec chamilo-chamilo-2 ls -l /var/www/html/prueba-ha.txt
docker exec chamilo-chamilo-1 rm /var/www/html/prueba-ha.txt
# inicie sesión en Chamilo desde Mint y luego:
docker exec chamilo-chamilo-2 ls /sessions
```

*Qué debe ver:* el archivo creado en la réplica 1 existe en la 2, y hay archivos `sess_…` en `/sessions` vistos desde la réplica 2.

> **Punto de control 2 (sí/no):** captura de `docker compose ps` con las dos réplicas sanas y de la prueba del archivo compartido y de `/sessions`.

**Pregunta de control:** ¿Qué pasaría con un usuario conectado si cada réplica guardara sus sesiones en su propio disco? ¿Qué pasaría si cada una tuviera su propio volumen de archivos?

## Bloque 3 — Ver el reparto y entender el balanceador (≈ 25 min)

Lea `docker/balanceador/nginx.conf`. Puntos que debe poder explicar:

| Línea | Qué hace | Diferencia con el ejemplo del profesor |
|---|---|---|
| `resolver 127.0.0.11 valid=5s` | Pregunta al DNS interno de Docker cada 5 s | El ejemplo no consulta: resuelve una vez al arrancar |
| `set $destino http://chamilo:80;` `proxy_pass $destino;` | Usa el **nombre del servicio**: Docker responde con las IP de las réplicas **vivas** | El ejemplo lista nombres de contenedor fijos (`…_1`, `…_2`) |
| `proxy_connect_timeout 2s` + `proxy_next_upstream …` | Si una réplica no responde, reintenta con otra | Sin esto, nginx espera hasta 60 s por el contenedor caído |
| `add_header X-Servidor $upstream_addr` | Muestra qué réplica atendió (para la demostración) | — |
| `proxy_next_upstream` no incluye `non_idempotent` | **No reintenta POST**: evita enviar dos veces una evaluación | — |

Veamos el reparto con el script del repositorio (una petición por segundo):

```bash
cd ~/proyecto-eif431o/docker
docker inspect -f '{{.Name}}  {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' chamilo-chamilo-1 chamilo-chamilo-2
./probar-ha.sh 15
docker compose logs --tail 15 balanceador
```

*Qué debe ver:* en `probar-ha.sh` el código `200` y **dos valores distintos** de `X-Servidor` (las IP de las dos réplicas, que `docker inspect` le ayuda a asociar con cada contenedor); el log del balanceador con `-> IP:80` alternando.

> **Punto de control 3 (sí/no):** captura de `docker inspect` (IP ↔ réplica) y de `probar-ha.sh` mostrando las dos IP.

**Pregunta de control:** ¿Cómo sabe nginx qué réplicas están vivas? ¿Qué diferencia hay con el balanceador del profesor?

## Bloque 4 — Prueba de caída y recuperación: **el corazón del bonus** (≈ 40 min)

Se hace con tres terminales (use `screen`, Sesión 14): **A** ejecuta `./probar-ha.sh 120`; **B** detiene y arranca contenedores; **Mint** tiene abierta una sesión de estudiante en el navegador.

1. En Mint inicie sesión como estudiante y navegue por el curso.
2. En **A** arranque `./probar-ha.sh 120`. En **B**, detenga la réplica que aparece primero en `X-Servidor`:

```bash
docker stop chamilo-chamilo-1
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

3. Mire **A**: debe verse que desaparece una IP y la otra sigue respondiendo `200`. En Mint **recargue y navegue**: la sesión continúa (sesiones compartidas).
4. Reincorpore la réplica y espere a que esté sana:

```bash
docker start chamilo-chamilo-1
docker inspect -f '{{.State.Health.Status}}' chamilo-chamilo-1     # repita hasta ver "healthy"
```

5. Repita con la réplica 2. Luego detenga **las dos**: debe ver `502`; arranque una y compruebe la recuperación.

Llene esta tabla con lo que **realmente observó** (no con lo que espera):

| Prueba | Hora | Peticiones fallidas durante el cambio | Segundos hasta que solo respondió la otra réplica | ¿Siguió la sesión del estudiante? | Segundos hasta reincorporarse |
|---|---|---|---|---|---|
| Detener réplica 1 | | | | | |
| Detener réplica 2 | | | | | |
| Detener ambas | | | n/a | n/a | |

> **Punto de control 4 (sí/no):** captura de `probar-ha.sh` cubriendo el cambio (con las horas), de `docker ps` con una réplica detenida, de Mint con la sesión abierta tras la caída, y la tabla completa.

**Pregunta de control:** ¿Qué ve el usuario cuando cae una réplica y cuando caen las dos? ¿Por qué `docker stop` de una réplica no hace que Docker la reinicie sola (`restart: unless-stopped`) y qué habría pasado con `docker kill`?

## Bloque 5 — ¿Se pierde algún dato? Dos pruebas (≈ 30 min)

El profesor mencionó que no debe haber pérdida de datos. Compruébelo en lo que sí se puede probar. **Escriba lo que ocurrió, aunque no sea lo ideal.**

**Prueba A — la base cae de golpe (con el Integrante 4).**

```bash
# 1) como Instructor, cree un usuario nuevo "prueba-datos" en Chamilo (queda confirmado)
docker kill chamilo-bd-1
watch -n 2 'docker ps --format "table {{.Names}}\t{{.Status}}"'      # Ctrl+C cuando bd esté healthy
# 2) vuelva a Chamilo: ¿existe "prueba-datos"?
```

*Qué debe ver:* `restart: unless-stopped` reinicia `bd`; mientras tanto Chamilo muestra error; al volver, el usuario **existe**: lo confirmado quedó en el volumen. Anote cuántos segundos duró la interrupción.

**Prueba B — una evaluación en curso durante el cambio de réplica.** Con un estudiante resolviendo el ejercicio de 5 preguntas, detenga la réplica que lo está atendiendo a mitad del intento, siga contestando y envíe. Verifique desde el Instructor que el intento y la nota quedaron registrados.

> **Punto de control 5 (sí/no):** capturas de ambas pruebas con el resultado real y una frase honesta sobre lo que **no** se pudo evitar (por ejemplo, una página enviada justo en el instante de la caída).

**Pregunta de control:** ¿Por qué lo confirmado antes de `docker kill` no se pierde? ¿Qué falla **no** cubre este diseño? *(Respuesta esperada: la caída de la VM completa; ver guía común, sección 0.)*

## Bloque 6 — Evaluación, usuarios y reporte del Instructor (≈ 90 min, con el Integrante 2)

**Objetivo.** Cumplir el requisito específico del escenario: *"Haga que un estudiante complete el curso y la evaluación — muestre el reporte de progreso/calificaciones visible desde el rol Instructor."* Los nombres de menú pueden variar según el idioma; documente los que usó.

1. **Usuarios.** Un **Instructor** (perfil *Profesor*) y **tres Estudiantes** con nombres de rol (operador, ayudante, maestro de obras) y correos `…@losangeles.internal`. Inscríbalos al curso "Seguridad en obra".
2. **Evaluación.** En la herramienta *Ejercicios*: mínimo **5 preguntas** (opción múltiple y verdadero/falso) del contenido de las lecciones, con puntaje, retroalimentación por respuesta y nota mínima de aprobación (p. ej. 80 %). Preguntas semilla en la guía común, sección 7. **Verifique cada respuesta correcta** contra la lección.
3. **Estudiante completa todo.** Un estudiante recorre las **3 lecciones** y aprueba la evaluación.
4. **Reporte del Instructor.** Con la sesión de Instructor, abra el seguimiento del curso (*Seguimiento / Reportes*) y muestre: el **progreso por estudiante** (porcentaje de lecciones), la **nota** y la fecha/hora del intento, y qué estudiantes **no** completaron. Esa pantalla responde al problema del caso: *"quién asistió y quién realmente entendió"*.
5. (Opcional) Configure un **certificado** de aprobación para quien alcance la nota mínima: refuerza la regla "nadie opera maquinaria sin aprobar".

> **Punto de control 6 (sí/no):** capturas de (a) la lista de usuarios con sus perfiles, (b) la evaluación con ≥ 5 preguntas, (c) el estudiante finalizando, (d) el **reporte desde el rol Instructor** con progreso y notas de los tres estudiantes.

**Pregunta de control:** ¿Cómo demuestra esta plataforma "quién completó la capacitación y quién la entendió", a diferencia de una charla presencial sin registro?

## Bloque 7 — Simulacro de recuperación de la VM (recomendado; con el Integrante 5)

Es la respuesta honesta a "se cae el equipo". Si dispone de una segunda VM:

1. VM2 limpia, repositorio clonado, mismo `.env` (misma URL y SHA-256).
2. Copie desde la VM1 los últimos respaldos (los trae la copia externa que prepara el Integrante 5).
3. `docker compose up -d bd`, `backups/restaurar.sh <respaldo-bd>`, `backups/restaurar-archivos.sh <respaldo-archivos>`.
4. Apunte el DNS a la VM2 (en la zona, cambie la `A` de `capacitacion` y suba el *serial*).
5. **Mida** el tiempo total (RTO) y calcule la edad del respaldo usado (RPO).

> **Punto de control 7 (sí/no):** tabla con RTO y RPO medidos y captura del sitio funcionando en la VM2 con los datos del curso.

**Pregunta de control:** ¿Qué parte de este procedimiento es manual y cómo se automatizaría? ¿Qué pierde el sistema, como máximo, en este caso?

## Etapa 3 (solo si el profesor exige conmutación automática entre VMs)

Fuera del temario y del repositorio del profesor: exigiría replicar la base entre dos VM, compartir los archivos y mover una IP flotante. **No la empiece** sin respuesta de la pregunta 1 y 2 de la guía común y sin tener cerrados los bloques 1 a 7. Las opciones y el riesgo están en la guía 4 (sección "Etapa 3").

## Entregables en el repositorio (PR)

`docker/probar-ha.sh` (si lo mejora), `docs/alta-disponibilidad.md` con arquitectura, tabla de pruebas, resultados reales y **puntos únicos de fallo** (Apache, la base, la VM), y evidencias y respuestas.

## Si algo falla

- **`probar-ha.sh` muestra una sola IP:** la segunda réplica no está *healthy* (`docker compose ps`) o nginx aún no actualizó (espere 5–10 s).
- **Tras detener una réplica hay unos segundos de errores:** es el tiempo hasta que Docker deja de responder su IP; anótelo en la tabla, no lo oculte.
- **Se pierde la sesión al cambiar de réplica:** compruebe que `/sessions` está montado en ambas (`docker exec … php -i | grep session.save_path` debe decir `/sessions`).
- **El segundo contenedor no arranca o queda `unhealthy`:** `docker compose logs chamilo`; el primer arranque **siempre** con una réplica (guía 2, bloque 3).
- **`docker stop` dice que no existe el contenedor:** el nombre cambia con la versión de Compose; léalo de `docker ps --format '{{.Names}}'`.
- **Todo da `502`:** no hay ninguna réplica sana; `docker compose ps` y `docker compose logs chamilo`.
