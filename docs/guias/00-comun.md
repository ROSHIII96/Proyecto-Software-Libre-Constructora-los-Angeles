# Guías por integrante — Proyecto EIF431O

**Constructora Los Ángeles · Chamilo LMS · Equipo Kernel Panic** · Entrega y demo: sesión 16, 07/11/2026

> Estas guías siguen el estilo de los laboratorios del profesor (Lab. #3 a #6): bloques cortos, comando, "qué debe ver", **punto de control** (captura) y **pregunta de control** (la responde por escrito y la debe poder explicar en la presentación). Todo parte de lo que ya hicieron: la VM Servidor Ubuntu 24.04, el cliente Mint, BIND9, Apache con VirtualHost HTTPS, Docker Compose con `mariadb:11.8`, Cron y `~/lab5`.

## 0. Qué cambia respecto del prompt maestro v2 (leer primero)

El prompt v2 lo escribí **antes** de leer el material del curso y del repositorio del profesor. Con ese material corrijo tres cosas, porque el proyecto se evalúa contra lo que el profesor enseñó, no contra una arquitectura más ambiciosa:

| Prompt v2 proponía | Estas guías usan | Por qué |
|---|---|---|
| HAProxy + keepalived | **Apache del servidor** como proxy HTTPS (VirtualHost + `ProxyPass` a `127.0.0.1:8081`) y **nginx** como balanceador dentro de Docker | El Lab. #5 (Bloque 5) hace exactamente el proxy con Apache. El balanceo con nginx y `--scale` es el que muestra el repositorio `cachac/dockerlabs` (`compose_loadbalancer`, capítulos 06 y 11). |
| MariaDB Galera de 3 nodos + GlusterFS | **Una MariaDB** (`mariadb:11.8`) con volumen con nombre, respaldos con Cron **y copia fuera del servidor**. Replicación = etapa 3, solo si el profesor la exige | El curso cubre volúmenes, respaldo y restauración; sobre replicación dice "hoy no lo implementamos". Galera con Chamilo no está probado y es el mayor riesgo de no llegar con una plataforma funcional. |
| Imagen de Chamilo "una sola vez" | **Se mantiene** (réplicas con la misma imagen, volúmenes compartidos) | Es lo que pide el bonus: dos instancias del mismo servicio. |

**Lo que SÍ cubre esta arquitectura y lo que no** (decirlo así en la presentación, es parte de "claridad sobre trade-offs"):

| Qué falla | Qué pasa | ¿Se pierden datos? |
|---|---|---|
| Cae una réplica de Chamilo | La otra responde sola; la sesión del usuario se conserva (sesiones en volumen compartido) | No |
| Muere el contenedor de MariaDB | El sitio se interrumpe unos segundos hasta que Docker lo reinicia (`restart: unless-stopped`) | No: las transacciones confirmadas están en el volumen (InnoDB) |
| Se cae o daña **la VM entera** | Sitio caído hasta recuperar en otra VM (manual) | Solo lo posterior al último respaldo, **si** el respaldo se copió fuera de esa VM |

La tercera fila **no es conmutación automática**. Si el profesor espera que otra máquina entre sola, hay que acordar con él el alcance (preguntas en la sección 6). No prometan "cero pérdida en cualquier caso".

## 1. Arquitectura y nombres comunes

```
 Cliente Mint ──DNS──► BIND9  (zona losangeles.internal)
      │
      └─ HTTPS :443 ─► Apache (VirtualHost + certificado) ─ProxyPass─► 127.0.0.1:8081
                                                                          │
                          ┌── Docker Compose (proyecto "chamilo") ────────┴──────────┐
                          │  balanceador  nginx:1.30-alpine  (reparte entre réplicas) │
                          │     ├─► chamilo (réplica 1)  ┐ misma imagen                │
                          │     └─► chamilo (réplica 2)  ┘ chamilo-app:1.11.40-php8.3  │
                          │  bd  mariadb:11.8   (sin ports)                            │
                          │  volúmenes: chamilo_datos_bd · chamilo_app · chamilo_sesiones │
                          └────────────────────────────────────────────────────────────┘
  vsftpd :21 (pasivo 40000-40100)        Cron ─► ~/respaldos (fuera de Docker) ─► copia externa
```

| Dato | Valor |
|---|---|
| Dominio / sitio | `losangeles.internal` / `capacitacion.losangeles.internal` |
| IP del servidor | `192.168.50.1` (topología del curso: `enp0s3` NAT + `enp0s8` red interna) |
| Carpeta del repositorio en el servidor | `~/proyecto-eif431o` (compose en `~/proyecto-eif431o/docker`) |
| Contenedores (los nombra Compose) | `chamilo-bd-1`, `chamilo-chamilo-1`, `chamilo-chamilo-2`, `chamilo-balanceador-1` (confirmar con `docker ps`) |
| Volúmenes | `chamilo_datos_bd`, `chamilo_app`, `chamilo_sesiones` |
| Respaldos | `~/respaldos` |

**Cada integrante puede levantar TODO esto solo en su propia VM** (igual que `~/lab5`): por eso nadie depende de la computadora de otro. La demostración final se monta en **un solo servidor limpio desde el repositorio**; eso es también la prueba de que "otra persona puede reproducir el trabajo".

> Antes de empezar: el Lab. #5 dejó en su servidor un `~/lab5` con el puerto **8081** y un VirtualHost `lab5docker`. Ejecute `cd ~/lab5 && docker compose down` (sin `-v`) para liberar el 8081. No borre nada más.

## 2. Versiones fijadas (verificadas hasta donde fue posible)

| Componente | Versión | Verificación |
|---|---|---|
| Ubuntu Server | 24.04 LTS | curso |
| Chamilo | **1.11.40** (24/06/2026, "stable") | Es la última etiqueta de la rama 1.11 del repositorio oficial y está en su `changelog` y en `main/install/version.php`. |
| PHP | **8.3** (`php:8.3-apache`), plan B **7.4** | La versión oficial de Chamilo 1.11 es **PHP 7.4** (`composer.json`, guía de instalación). El `changelog` dice que 8.3 "no está totalmente probado, pero tiene posibilidades razonables". El Lab. #5 usa `php:8.3-apache`. **Se decide con la prueba de humo** (guía 2, bloque 5). PHP 7.4 está fuera de soporte: si hay que usarlo, se documenta como riesgo. |
| MariaDB | **`mariadb:11.8`**, plan B `mariadb:10.11` | Es la imagen de los Lab. #4–#6. La guía de Chamilo exige "MySQL 5.6+ o cualquier MariaDB", pero **no hay prueba con 11.8**: se confirma con la prueba de humo. |
| nginx | `nginx:1.30-alpine` | Sesión 12 |
| Apache, BIND9, vsftpd | paquetes de Ubuntu 24.04 | curso |

Existe **Chamilo 2.0.x** (etiquetas hasta 2.0.3). No lo usamos: otra arquitectura (Symfony/API), sin material en el curso y el equipo pidió "estable, no la más nueva". Es un buen punto para justificar en la presentación.

No pude descargar ni ejecutar nada de Docker Hub desde mi entorno: **las imágenes, el instalador de Chamilo y los comandos de Docker no los probé de punta a punta**. Validé la sintaxis del `docker-compose.yml` y de los scripts; el resto lo revisé a mano. Cualquier ajuste que descubran, regístrenlo en `docs/decisiones.md`.

## 3. Trabajo con Git (todos)

```bash
git clone <URL-del-repositorio> ~/proyecto-eif431o && cd ~/proyecto-eif431o
git switch -c int1-dns-https                # int2-chamilo-imagen, int3-alta-disponibilidad, int4-mariadb, int5-ftp-respaldos
# ... trabaje, pruebe ...
git add -A && git status                    # REVISE que no aparezcan .env, llaves, respaldos ni .zip
git commit -m "Int1: zona DNS y VirtualHost HTTPS"
git push -u origin int1-dns-https           # abrir Pull Request; lo revisa otro integrante
```

Reglas: nada directo a `main`; un PR revisado por otra persona; **jamás** `.env`, `*.key`, `*.sql.gz`, `*.zip`. El `.gitignore` ya los excluye: no lo desactiven. Las evidencias van en `docs/evidencias/intN/` con nombre `PCx-descripcion.png`; las respuestas a las preguntas de control en `docs/guias/respuestas-intN.md`.

## 4. Quién desbloquea a quién (para que nadie espere)

| Quién | Qué entrega | A quién desbloquea | Fecha límite |
|---|---|---|---|
| **Int. 2** | Rama con `docker/` completo (aunque Chamilo aún no esté instalado) | 3, 4, 5 | **Lun 26/10 noche** |
| **Int. 1** | Zona DNS + VirtualHost HTTPS funcionando con una página de prueba | 2 (instalar Chamilo por el dominio HTTPS) | Lun 26/10 |
| **Int. 4** | Resultado de la **prueba de humo** (Chamilo 1.11.40 + PHP 8.3 + MariaDB 11.8) | Todos (fija las versiones) | **Mar 27/10** |
| Int. 3 y 5 | Mientras esperan a Int. 2, trabajan con el repositorio del profesor y con `~/lab5` (ver sus guías) | — | — |

## 5. Calendario hasta la entrega

| Fecha | Meta |
|---|---|
| Dom 25 – Mar 27/10 | Cada módulo funcionando en la VM de su responsable; PR abiertos |
| Mié 28/10 | Revisión cruzada de PR; versiones cerradas; respuestas del profesor (sección 6) |
| Jue 29 – Vie 30/10 | **Despliegue desde cero** en un servidor limpio siguiendo solo el repositorio; corregir lo que falle |
| Sáb 31/10 (sesión 15, repaso) | Pruebas de alta disponibilidad y respaldo/restauración con todos presentes |
| Dom 1 – Mié 4/11 | Evidencias, documento técnico, costos, justificación de software libre, video de respaldo de la demo |
| Jue 5/11 | Documento congelado |
| Vie 6/11 | Ensayo general (guion con tiempos y responsable por componente, banco de preguntas) |
| Sáb 7/11 | Sesión 16: demo y presentación |

## 6. Preguntas para el profesor (antes del miércoles 28/10)

1. El bonus pide "dos instancias del mismo servicio". ¿Le basta con dos réplicas de la aplicación detrás de un balanceador (como `compose_loadbalancer`), o quiere ver también que caiga y se recupere la base de datos o la VM completa?
2. Cuando dijo "sin pérdida de datos": ¿acepta que sea "ninguna transacción confirmada se pierde, y la VM se recupera desde un respaldo copiado fuera del servidor"?
3. ¿Puede la demostración correr en **una** laptop con Servidor + Mint (topología del curso), o necesita ver varias máquinas?
4. Chamilo 1.11 es oficialmente PHP 7.4. ¿Acepta que usemos PHP 8.3 si pasa la prueba de humo (y 7.4 con el riesgo documentado si no pasa)?

## 7. Contenido del curso "Seguridad en obra" (lo redactan Int. 2 y 3)

El requisito es contenido **genuino**, no de relleno. Propuesta de estructura, pensada para el incidente del caso (un trabajador sin capacitación completa operó maquinaria):

| Elemento | Contenido sugerido | Quién |
|---|---|---|
| Lección 1 | Equipo de protección personal: qué es, cuándo es obligatorio, cómo se inspecciona (casco, calzado, lentes, guantes, protección auditiva, chaleco, arnés) y errores comunes | Int. 2 |
| Lección 2 | Trabajo en altura, andamios y escaleras: anclaje del arnés, revisión de andamios antes de usarlos, orden y limpieza | Int. 2 |
| Lección 3 | **Operación segura de maquinaria**: nadie opera un equipo sin autorización escrita, inspección previa, zona de exclusión, señalero, qué hacer ante una falla. Cierra con la regla de la empresa: *no se autoriza a operar maquinaria sin aprobar esta evaluación* | Int. 2 |
| Recurso descargable (PDF) | "Lista de verificación diaria de maquinaria" o "Guía rápida de EPP", de 1–2 páginas, redactada por ustedes | Int. 2 (lo sube) |
| Evaluación | Mínimo 5 preguntas (recomendado 10), nota mínima definida (p. ej. 80 %), con retroalimentación por respuesta | Int. 3 |
| Usuarios | 1 Instructor (perfil Profesor) y 3 Estudiantes con nombres de **rol** (operador, ayudante, maestro de obras); nada de datos personales reales | Int. 3 |
| Prueba | Un estudiante completa las lecciones y la evaluación; el Instructor muestra el reporte de progreso/calificaciones | Int. 3 |

Citen las fuentes de contenido (normativa costarricense de seguridad en construcciones y del Consejo de Salud Ocupacional, material del INS): **verifiquen cada dato en la fuente antes de ponerlo**; no copien cifras de memoria. Preguntas semilla (ajústenlas): ¿Qué se debe hacer *antes* de operar por primera vez una máquina de la obra? ¿A qué se ancla un arnés? ¿Qué hace usted si ve a un compañero sin casco en una zona con riesgo de caída de objetos? ¿Quién puede autorizar a un trabajador a operar maquinaria?

## 8. Formato de entrega de cada integrante

Para cada bloque de su guía: (1) la captura del **punto de control** en `docs/evidencias/intN/`, (2) la respuesta escrita a la **pregunta de control** en `docs/guias/respuestas-intN.md`, (3) sus archivos en el repositorio por PR. En la presentación cada uno explica su componente **sin leer**: las preguntas de control son el ensayo.
