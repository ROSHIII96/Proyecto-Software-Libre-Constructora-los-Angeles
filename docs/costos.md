# Análisis de costos — Proyecto Constructora Los Ángeles

## Objetivo

Este documento compara el costo aproximado de mantener una plataforma de capacitación basada en software libre frente a una capacitación principalmente presencial y sin una plataforma centralizada de registros.

Los montos que no se conocen con exactitud se indican como supuestos o como pendientes de cotización.

---

## 1. Costos iniciales de la plataforma

### Licencias de software

Chamilo LMS:

₡0 por licencia de software.

MariaDB:

₡0 por licencia de software.

Nginx:

₡0 por licencia de software.

BIND9:

₡0 por licencia de software.

vsftpd:

₡0 por licencia de software.

Docker Engine:

₡0 por licencia del motor utilizado en el servidor Linux.

Linux:

₡0 por licencia del sistema operativo utilizado.

Total inicial en licencias de los componentes principales:

₡0

Esto no significa que implementar el sistema no tenga costo.

El costo principal corresponde al tiempo de instalación, configuración, mantenimiento, electricidad, hardware e Internet.

Chamilo se distribuye como software libre bajo GPLv3+.

Fuente:

https://chamilo.org/es/chamilo/

Docker Engine es un proyecto de código abierto.

Fuente:

https://docs.docker.com/engine/

---

## 2. Hardware

Para este proyecto se reutilizó infraestructura existente durante las pruebas.

Por esta razón se considera:

Costo adicional de hardware para el prototipo académico:

₡0

Para una implementación real en la empresa, el costo dependerá de si ya existe un equipo que pueda utilizarse como servidor.

Si se requiere comprar un servidor nuevo:

Costo:

Pendiente de cotización.

Fórmula:

Costo inicial de hardware = precio del servidor + almacenamiento adicional + equipo de respaldo necesario

No se asigna un precio específico porque el proyecto no posee una cotización real de hardware.

---

## 3. Mano de obra para implementación

La instalación y configuración requiere tiempo técnico.

Para estimar este costo se puede utilizar:

Costo de implementación = horas de trabajo × costo por hora

Como referencia oficial, el Ministerio de Trabajo y Seguridad Social publica los salarios mínimos del sector privado.

Para 2026 se reportan, entre otros:

Trabajador en ocupación especializada:

₡16.244,50 por jornada diaria.

Bachiller universitario:

₡664.078,07 mensuales.

Fuente oficial:

https://www.mtss.go.cr/temas-laborales/salarios/lista_salarios_minimos_2026.pdf

Ejemplo de cálculo:

Si una implementación requiere 20 horas:

Costo estimado = 20 horas × tarifa técnica por hora

El monto final debe calcularse utilizando la tarifa real del técnico o proveedor contratado.

Por lo tanto:

Costo de implementación:

Pendiente de tarifa real o cotización.

---

## 4. Electricidad

El servidor necesita permanecer encendido para que la plataforma esté disponible.

La electricidad en Costa Rica se cobra según el consumo en kilovatios hora y la tarifa de la empresa distribuidora.

Fuente oficial:

https://aresep.go.cr/electricidad/tarifas/

La fórmula utilizada es:

Consumo mensual = potencia del servidor en kW × horas de uso diario × días del mes

Costo mensual = consumo mensual en kWh × tarifa eléctrica aplicable

Ejemplo:

Si un equipo consume 0,15 kW y permanece encendido 24 horas:

0,15 × 24 × 30 = 108 kWh mensuales

Después:

108 kWh × tarifa de la empresa eléctrica = costo mensual de electricidad

No se coloca una tarifa fija porque depende de la empresa distribuidora, tipo de servicio y tarifa vigente.

Costo:

Variable según consumo y distribuidora.

---

## 5. Internet

La plataforma puede funcionar dentro de la red interna sin contratar un servicio de Internet adicional.

Si la empresa ya cuenta con conexión a Internet:

Costo adicional aproximado:

₡0

Esto es un supuesto basado en reutilizar la conexión existente.

Si se requiere una conexión exclusiva para el servidor:

Costo:

Pendiente de cotización con el proveedor.

---

## 6. Respaldos

Los respaldos se almacenan inicialmente en:

~/respaldos

Además se realiza una copia hacia una segunda máquina Linux mediante SSH y rsync.

Si se reutiliza una computadora existente como destino:

Costo adicional de software:

₡0

Costo de almacenamiento:

Depende del disco disponible y de la cantidad de información generada.

Si se requiere comprar un disco adicional:

Costo:

Pendiente de cotización.

---

## 7. Mantenimiento

La plataforma requiere tareas periódicas como:

- actualizar el sistema;
- actualizar contenedores;
- revisar los respaldos;
- realizar pruebas de restauración;
- revisar espacio disponible;
- mantener usuarios y cursos;
- revisar certificados y configuraciones.

Fórmula:

Costo mensual de mantenimiento = horas mensuales × tarifa del responsable técnico

Ejemplo:

Si se utilizan 4 horas mensuales:

Costo mensual = 4 × tarifa técnica por hora

Costo real:

Pendiente de definir según la persona o empresa que brinde el mantenimiento.

---

## 8. Costos recurrentes de la plataforma

Los principales costos recurrentes serían:

Electricidad:

Variable.

Internet:

₡0 adicional si se utiliza la conexión existente.

Licencias de software:

₡0 para los componentes libres utilizados.

Mantenimiento técnico:

Variable.

Almacenamiento:

Variable dependiendo del crecimiento de los respaldos.

---

## 9. Comparación con capacitación presencial

Sin una plataforma LMS, una empresa puede depender de capacitaciones presenciales y registros manuales.

Los costos pueden incluir:

- tiempo del instructor;
- tiempo de los trabajadores;
- transporte;
- materiales impresos;
- espacio físico;
- alimentación;
- repetición de sesiones para trabajadores ausentes;
- manejo manual de listas y resultados.

Fórmula general:

Costo presencial =
costo del instructor
+ costo del tiempo de los trabajadores
+ transporte
+ materiales
+ espacio
+ otros gastos

Los valores reales deben obtenerse mediante una cotización o datos internos de la empresa.

Por esta razón:

Costo de instructor:

Pendiente de cotización.

Costo de transporte:

Pendiente de cotización.

Costo de materiales:

Pendiente de cotización.

Costo del espacio:

Pendiente de cotización.

---

## 10. Ejemplo de comparación

Escenario con plataforma:

Licencias de software = ₡0

Hardware adicional = ₡0 si se reutiliza un equipo

Internet adicional = ₡0 si ya existe conexión

Electricidad = variable

Mantenimiento = variable

Implementación inicial = variable según horas técnicas

Escenario presencial:

Instructor = variable

Transporte = variable

Materiales = variable

Tiempo de los trabajadores = variable

Repetición de capacitaciones = variable

Registro y seguimiento manual = requiere tiempo administrativo

---

## 11. Beneficios económicos de la plataforma

El uso de la plataforma puede reducir algunos costos indirectos.

Por ejemplo:

- un mismo curso puede reutilizarse;
- el trabajador puede realizar actividades sin repetir una sesión completa con instructor;
- los resultados quedan almacenados;
- se reduce el uso de papel;
- se facilita comprobar quién realizó una capacitación;
- los cursos pueden mantenerse disponibles para nuevos trabajadores;
- se disminuye el trabajo administrativo de llevar registros manuales.

No todos estos beneficios representan un ahorro automático.

El ahorro real depende del número de trabajadores, cantidad de capacitaciones y forma en que la empresa utilice la plataforma.

---

## 12. Costos iniciales y recurrentes

Costos iniciales:

- instalación y configuración;
- posible compra de hardware;
- preparación de cursos;
- configuración de usuarios;
- pruebas de la plataforma.

Costos recurrentes:

- electricidad;
- mantenimiento;
- almacenamiento;
- Internet si se requiere un servicio adicional;
- actualización de contenidos.

---

## 13. Resumen

Software:

₡0 en licencias para los componentes principales utilizados.

Hardware:

₡0 adicional si se reutiliza infraestructura existente.

En caso de compra:

Pendiente de cotización.

Electricidad:

Consumo en kWh × tarifa vigente.

Mantenimiento:

Horas de trabajo × tarifa técnica.

Internet:

₡0 adicional si se reutiliza la conexión existente.

Capacitación presencial:

Pendiente de cotización según instructor, transporte, materiales y tiempo utilizado.

---

## 14. Conclusión

El uso de software libre reduce el costo inicial relacionado con licencias.

Sin embargo, una solución de software libre no debe considerarse completamente gratuita.

Existen costos asociados con:

- implementación;
- hardware;
- electricidad;
- mantenimiento;
- respaldos;
- administración.

La principal ventaja económica del proyecto es que no se requiere pagar una licencia por cada usuario de Chamilo, MariaDB, Nginx, BIND9, vsftpd o Linux.

Además, la plataforma puede reutilizar cursos y mantener registros digitales, lo que puede reducir parte de los costos y trabajo asociados con capacitaciones presenciales repetitivas.

Para una estimación económica definitiva se deben solicitar cotizaciones reales de hardware, mantenimiento, Internet y capacitación presencial.
