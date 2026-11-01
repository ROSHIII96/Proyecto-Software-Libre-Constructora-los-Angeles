## Plan de Monitoreo del Sistema

Para garantizar el correcto funcionamiento y la alta disponibilidad de la plataforma dentro de la empresa, se ha establecido un conjunto de tareas estructuradas por áreas clave de supervisión.

Áreas de Monitoreo

1. `Almacenamiento` y Recursos (Espacio)

Con el objetivo de prevenir degradaciones en el rendimiento o interrupciones del servicio causadas por la saturación de almacenamiento, se implementará un monitoreo continuo de:

Servidor principal: Control del uso del disco y memoria RAM en la máquina host.

Volúmenes de Docker: Supervisión del espacio ocupado por los volúmenes encargados de la persistencia de datos.

2. `Gestión de Eventos` (Logs)

Para facilitar la auditoría, el diagnóstico temprano y la resolución de incidentes:

Registro de actividad: Seguimiento continuo de los logs generados por la plataforma y sus componentes.

Respaldo y retención: Almacenamiento seguro de registros en el servidor local y en copias de seguridad externas para garantizar la recuperabilidad ante fallos críticos.

3. `Seguridad y Red` (Conexiones)

Con el fin de resguardar la integridad del sistema y prevenir accesos no autorizados:

Puertos y tráfico: Monitoreo constante de los puertos expuestos y las conexiones entrantes/salientes.

Control de acceso: Verificación periódica de reglas de red para asegurar que solo los puertos y direcciones autorizados tengan permiso para interactuar con la plataforma.