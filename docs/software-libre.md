# Software libre utilizado en el proyecto

El proyecto Constructora Los Ángeles utiliza principalmente herramientas de software libre y código abierto.

Esto permite utilizar, estudiar y adaptar las herramientas sin pagar licencias por usuario para los componentes principales utilizados en la plataforma.

## Componentes utilizados

### Chamilo LMS

Software:

Chamilo LMS 1.11.40

Licencia:

GNU General Public License versión 3 o posterior (GPLv3+)

Uso en el proyecto:

Chamilo es la plataforma LMS utilizada para administrar usuarios, cursos, evaluaciones y actividades de capacitación.

Fuente oficial:

https://chamilo.org/en/download/

La página oficial indica que Chamilo LMS se distribuye como software libre bajo GNU/GPLv3+.


### MariaDB

Software:

MariaDB 11.8

Licencia:

GNU General Public License versión 2 (GPLv2)

Uso en el proyecto:

MariaDB almacena la información utilizada por Chamilo, incluyendo usuarios, cursos, configuraciones y demás datos de la plataforma.

Fuente oficial:

https://mariadb.com/docs/general-resources/community/community/faq/licensing-questions/licensing-faq

MariaDB indica oficialmente que el servidor MariaDB se distribuye bajo GPL versión 2.


### Nginx

Software:

Nginx

Licencia:

BSD de 2 cláusulas

Uso en el proyecto:

Se utiliza Nginx en dos partes:

- como servidor proxy HTTPS;
- como balanceador dentro de Docker.

Fuente oficial:

https://nginx.org/

La página oficial indica que Nginx se distribuye bajo la licencia BSD de 2 cláusulas.


### BIND9

Software:

BIND9

Licencia:

Mozilla Public License 2.0 (MPL 2.0)

Uso en el proyecto:

BIND9 proporciona el servicio DNS interno y permite resolver:

capacitacion.losangeles.internal

Fuente oficial:

https://www.isc.org/bind/

ISC indica que las versiones actuales de BIND9 se distribuyen bajo MPL 2.0.


### vsftpd

Software:

vsftpd

Licencia:

GPL

Uso en el proyecto:

vsftpd proporciona el servicio FTP utilizado por los integrantes del proyecto.

Se configuraron usuarios aislados y puertos pasivos.

Fuente oficial:

https://security.appspot.com/vsftpd.html

El sitio oficial describe vsftpd como un servidor FTP distribuido bajo licencia GPL.


### Docker Engine

Software:

Docker Engine

Licencia:

Apache License 2.0

Uso en el proyecto:

Docker permite ejecutar los servicios de Chamilo, MariaDB y el balanceador en contenedores.

Fuente oficial:

https://docs.docker.com/engine/install/

La documentación oficial indica que Docker Engine es un proyecto de código abierto distribuido bajo Apache License 2.0.


### Linux

Software:

Linux

Licencia:

GNU General Public License versión 2

Uso en el proyecto:

Linux es la base de los servidores y máquinas utilizadas durante el desarrollo y las pruebas.

Fuente oficial:

https://www.kernel.org/faq.html

Kernel.org indica que el kernel Linux se distribuye bajo GNU GPL versión 2.

## Beneficios del software libre para el proyecto

El uso de software libre aporta varias ventajas.

### Reducción de costos

Las herramientas principales utilizadas no requieren pagar licencias por cada usuario del sistema.

Esto permite implementar una plataforma de capacitación sin adquirir licencias comerciales para Chamilo, MariaDB, Nginx, BIND9, vsftpd o Docker Engine.

### Acceso al código

El código fuente de muchas de las herramientas puede ser revisado y modificado.

Esto facilita estudiar cómo funcionan las tecnologías utilizadas.

### Independencia de proveedor

La empresa no queda obligada a utilizar un único proveedor comercial.

Los servicios pueden migrarse a otro servidor o ser administrados por otro equipo técnico.

### Personalización

Chamilo y los demás componentes pueden configurarse según las necesidades de la organización.

### Comunidad y documentación

Los proyectos utilizados poseen documentación y comunidades que permiten encontrar soluciones y actualizaciones.

## Comparación con Moodle

Moodle también es una plataforma LMS de software libre y es una alternativa válida para capacitación.

Tanto Moodle como Chamilo permiten:

- crear cursos;
- administrar usuarios;
- realizar evaluaciones;
- registrar progreso;
- utilizar complementos y personalizaciones.

Para este proyecto se utilizó Chamilo porque fue la plataforma asignada para la solución desarrollada por el equipo.

No se afirma que Chamilo sea superior a Moodle en todos los escenarios.

La elección depende de las necesidades, experiencia del equipo, infraestructura disponible y requerimientos de cada organización.

## Conclusión

La solución desarrollada se apoya principalmente en tecnologías de software libre.

Esto permite construir una plataforma funcional de capacitación evitando costos de licencia por usuario en los principales componentes del sistema.

Además, facilita la personalización, el aprendizaje técnico y la posibilidad de administrar la infraestructura sin depender completamente de un proveedor propietario.
