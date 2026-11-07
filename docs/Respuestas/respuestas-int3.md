# Respuestas Integrante 3

Este archivo contiene únicamente los bloques y preguntas asignados al Integrante 3 en la guía del equipo. Los bloques 5, 6 y 7 requieren coordinación con otros integrantes, pero permanecen aquí porque el Integrante 3 debe explicar la relación de esas pruebas con la alta disponibilidad, el curso y la recuperación.

Los compañeros documentan sus propios componentes en sus archivos:

- Integrante 2: instalación, contenido base y prueba de Chamilo.
- Integrante 4: MariaDB, persistencia y seguridad de datos.
- Integrante 5: respaldos, restauración y copia externa.

# Bloque 1 — Balanceador del laboratorio

# Punto de control 1

El balanceador del laboratorio falla cuando cae un contenedor porque utiliza una lista fija de servidores y no realiza una comprobación dinámica de salud. Además, el ejemplo puede usar nombres de contenedor con guion bajo, mientras que Compose v2 crea nombres con guiones.

Las dos cosas fijas son:

- los nombres o direcciones de los servidores upstream;
- la lista de réplicas configurada en nginx.

# Pregunta de control

¿Por qué falla ese balanceador cuando un contenedor cae, y qué dos cosas están “fijas” en su configuración?

Falla porque nginx continúa intentando enviar tráfico a una dirección que ya no responde. La configuración fija tanto los servidores upstream como la lista de réplicas; por eso no descubre automáticamente que un contenedor fue detenido ni incorpora uno nuevo.

# Bloque 2 — Segunda réplica y volúmenes compartidos

# Punto de control 2

Estado: Implementado en `docker-compose.yml`;

Las réplicas se levantan con:

    cd ~/proyecto-eif431o/docker
    docker compose up -d --scale chamilo=2
    docker compose ps

Ambas réplicas comparten:

- `chamilo_app`, montado en `/var/www/html`;
- `chamilo_sesiones`, montado en `/sessions`.

La prueba del archivo compartido se realiza con:

    docker exec chamilo-chamilo-1 touch /var/www/html/prueba-ha.txt
    docker exec chamilo-chamilo-2 ls -l /var/www/html/prueba-ha.txt
    docker exec chamilo-chamilo-1 rm /var/www/html/prueba-ha.txt

Después de iniciar sesión en Chamilo se comprueba la sesión con:

    docker exec chamilo-chamilo-2 ls /sessions

# Pregunta de control

¿Qué pasaría con un usuario conectado si cada réplica guardara sus sesiones en su propio disco? ¿Qué pasaría si cada una tuviera su propio volumen de archivos?

El usuario podría perder la sesión al cambiar de réplica porque la segunda instancia no encontraría la cookie de sesión en su disco local. Si cada réplica tuviera sus propios archivos, una instancia podría no encontrar los cursos, documentos o archivos subidos desde la otra. Los volúmenes compartidos evitan ambos problemas.


# Bloque 3 — Balanceo dinámico

# Punto de control 3

El balanceador usa el DNS interno de Docker:

    resolver 127.0.0.11 valid=5s ipv6=off;

Y envía las solicitudes al nombre del servicio:

    set $destino http://chamilo:80;
    proxy_pass $destino;

La comprobación se realiza con:

    docker inspect -f '{{.Name}}  {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' chamilo-chamilo-1 chamilo-chamilo-2
    ./probar-ha.sh 15
    docker compose logs --tail 15 balanceador

# Pregunta de control

¿Cómo sabe nginx qué réplicas están vivas? ¿Qué diferencia hay con el balanceador del profesor?

nginx consulta cada cinco segundos el DNS interno de Docker. Docker devuelve las direcciones de las réplicas disponibles del servicio `chamilo`. Si una no responde, `proxy_next_upstream` permite intentar otra.

El balanceador del profesor utiliza servidores fijos y resuelve la lista al iniciar. El del proyecto usa el nombre del servicio, actualiza las direcciones mediante el DNS de Docker y reintenta ante errores de conexión.

# Bloque 4 — Caída y recuperación de réplicas

# Punto de control 4

La prueba se realiza ejecutando:

    ./probar-ha.sh 120

Mientras se detiene una réplica:

    docker stop chamilo-chamilo-1
    docker ps --format 'table {{.Names}}\t{{.Status}}'

Si cae una réplica, la otra debe continuar respondiendo con HTTP 200 y la sesión debe conservarse porque `/sessions` es compartido. Si caen las dos, el balanceador devuelve HTTP 502 porque no queda ninguna réplica disponible.

`docker stop` no reinicia automáticamente el contenedor porque `restart: unless-stopped` no reinicia un contenedor detenido manualmente. Sí permite recuperar un proceso que termina o falla.

# Pregunta de control

¿Qué ve el usuario cuando cae una réplica y cuando caen las dos?

Cuando cae una réplica, puede existir un breve periodo con errores mientras Docker deja de anunciarla, pero después las solicitudes son atendidas por la otra réplica. La sesión continúa gracias al volumen compartido de sesiones. Cuando caen las dos, el usuario recibe un error 502 hasta que vuelve a estar disponible al menos una réplica.

# Bloque 5 — Persistencia de datos durante fallos

**Responsabilidad:** Integrante 3, con apoyo del Integrante 4 para MariaDB.

# Punto de control 5

La base de datos utiliza el volumen persistente `chamilo_datos_bd`. Por eso, un usuario creado y confirmado antes de detener MariaDB debe seguir existiendo después de que el contenedor se reinicie.

También debe probarse una evaluación en curso mientras se detiene la réplica que atiende al estudiante. Una página enviada exactamente durante la caída podría fallar y debe registrarse como resultado real, no ocultarse.

# Pregunta de control

¿Por qué lo confirmado antes de `docker kill` no se pierde? ¿Qué falla no cubre este diseño?

Lo confirmado no se pierde porque MariaDB guarda los datos en `chamilo_datos_bd` y las transacciones confirmadas quedan persistidas en InnoDB. Reiniciar el contenedor no elimina ese volumen.

Este diseño no cubre la pérdida completa de la máquina virtual. Para ese caso se necesitan respaldos externos y restauración en otra VM.

# Bloque 6 — Usuarios, evaluación y reporte del Instructor

**Responsabilidad:** Integrante 3, con apoyo del Integrante 2 para la instalación y el contenido de Chamilo.

# Punto de control 6

Estado: La automatización incluye el curso, usuarios y evaluación; pendiente de verificar las capturas finales desde Chamilo.

El curso debe incluir:

- un Instructor con perfil Profesor;
- tres estudiantes inscritos;
- tres lecciones;
- una evaluación de al menos cinco preguntas;
- puntaje, retroalimentación y nota mínima de aprobación.

La prueba consiste en que un estudiante recorra las tres lecciones, apruebe la evaluación y el Instructor consulte el seguimiento del curso.

# Pregunta de control

¿Cómo demuestra esta plataforma quién completó la capacitación y quién la entendió, a diferencia de una charla presencial sin registro?

Chamilo registra los usuarios inscritos, el progreso de las lecciones, los intentos, las calificaciones y la fecha y hora de la evaluación. El Instructor puede consultar esos datos y distinguir entre quien solamente estuvo inscrito, quien completó el contenido y quien aprobó la evaluación. Una charla presencial normalmente no deja ese nivel de evidencia individual verificable.

# Bloque 7 — Recuperación de la VM

**Responsabilidad:** Integrante 3, con apoyo del Integrante 5 para respaldos y restauración.

# Punto de control 7

Estado: El procedimiento está documentado

La recuperación manual consiste en:

1. preparar una VM nueva;
2. clonar el repositorio;
3. copiar los respaldos externos;
4. levantar MariaDB;
5. restaurar la base y los archivos de Chamilo;
6. actualizar el registro DNS;
7. verificar el sitio y los datos del curso.

### Pregunta de control

¿Qué parte es manual y cómo se automatizaría? ¿Qué pierde el sistema, como máximo, en este caso?

Son manuales la preparación de la VM, la copia de los respaldos, la restauración, el cambio del DNS y la verificación final. Se podría automatizar con un script de recuperación, infraestructura reproducible, actualización controlada del DNS y monitoreo.

Como máximo se perderían los cambios realizados después del respaldo utilizado. Ese intervalo corresponde al RPO medido para la copia restaurada.

---

## Resumen del estado

La configuración del integrante 3 ya contempla dos réplicas de Chamilo, volúmenes compartidos, balanceo dinámico y reintento ante fallos. Los puntos que todavía requieren evidencia ejecutada son las capturas de los bloques 1 a 7 y los tiempos reales de caída, recuperación, RTO y RPO.
