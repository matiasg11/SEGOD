# Manual de uso — SEGOD Laboratorio

## 1. Ingreso

La aplicación está disponible en:

- GitHub Pages: <https://matiasg11.github.io/SEGOD/>
- SEGOD Sites: <https://segod-laboratorio.matiasg11.chatgpt.site/>

Se puede ingresar con el usuario corto (por ejemplo, `matias.guarnera`) o con el correo completo. La contraseña se puede recuperar desde **Olvidé mi contraseña** y cambiar desde **Mi cuenta**, donde se solicita la contraseña actual.

## 2. Navegación

En computadora, las secciones están en la barra lateral. En teléfono o tablet, el botón azul de tres líneas del encabezado abre el menú completo. Al elegir una sección, el menú se cierra automáticamente.

El buscador del encabezado filtra la sección visible. Los indicadores del **Resumen** son botones: al tocar un valor, la aplicación abre el listado correspondiente con el mismo filtro aplicado. Por ejemplo, **Muestras pendientes** lleva solamente a esas muestras y **Equipos vencidos** lleva al inventario filtrado por vencimiento.

Las tarjetas de ensayos, informes, equipos y grupos de datos crudos muestran primero un resumen. Para ver toda la ficha y sus acciones, tocar **Ver detalle**, **Ver ficha**, **Ver resumen de ensayos** o **Ver datos**.

## 3. Muestras

### Crear una muestra

1. Tocar **+ Nueva muestra**.
2. Completar la identificación. La fecha, solicitante, cantidad y campos N/A ya tienen valores predeterminados.
3. Elegir la norma. IRAM 3607, IRAM 3608 y Ensayos de rutina seleccionan automáticamente sus ensayos; la selección se puede ajustar manualmente.
4. Elegir el responsable. Si no se informa uno, el flujo utiliza a Gonzalo Torti como responsable predeterminado.
5. Guardar. Se crea un ID interno único y los ensayos quedan **Pendiente**.

### Buscar, ordenar y filtrar

En **Muestras** se puede ordenar por ingreso, nombre, ID, material o solicitante. El selector de estado permite ver todas, las pendientes/abiertas, las ingresadas hoy o un estado concreto.

### Acciones en lote

1. Marcar muestras individuales o **Seleccionar las visibles**.
2. Elegir una acción: enviar a revisión, aprobar, observar o marcar como No Ensayado.
3. Tocar **Aplicar**.

La acción afecta solamente los ensayos vigentes y compatibles con esa transición.

### Editar o eliminar

El administrador y el Responsable del laboratorio pueden editar una muestra. Al cambiar los ensayos asignados, los marcados se agregan y los desmarcados se archivan con trazabilidad. Al eliminar una muestra, también se archivan sus ensayos asociados; la auditoría conserva el historial.

## 4. Ensayos

En **Ensayos** se puede ordenar y filtrar por estado, seleccionar varios y enviarlos juntos a revisión. Los aprobados permanecen ocultos en la vista activa y se muestran al cambiar el filtro.

Abrir una tarjeta para:

- cambiar el estado;
- agregar una nueva secuencia de datos;
- cambiar ensayo o responsable (administrador);
- repetir, enviar a revisión, aprobar, observar o marcar No Ensayado;
- eliminar el ensayo con motivo y opción inmediata de deshacer.

Las unidades, el formulario y el equipo principal se completan según el catálogo. Los valores vacíos se consideran N/A y no participan de promedios ni niveles. En pH, el índice de diferencia y el cumplimiento se calculan automáticamente.

## 5. Datos crudos

Los datos crudos son **inmutables**. Un usuario autorizado puede agregar una medición, pero ningún usuario de la aplicación —incluido el administrador— puede sobrescribirla o eliminarla.

Si se necesita corregir un dato:

1. abrir el ensayo;
2. tocar **Agregar datos**;
3. cargar la corrección en la siguiente secuencia sugerida;
4. explicar el motivo en Observaciones y guardar.

La sección **Datos crudos** está reservada al administrador y agrupa registros por muestra y ensayo. **Exportar backup** descarga una copia de la base para resguardo.

## 6. Informes

**Informes** contiene el resumen consolidado por muestra. Cada tarjeta se puede ampliar, revisar en pantalla y descargar en PDF. El archivo se nombra `QF-04 <nombre de muestra> <yyyymmdd>.pdf` y contiene identificación, método, resultados, unidades, niveles, cumplimiento, responsables, equipos y un QR final con el resumen tabulado para validación.

## 7. Personal, equipos y documentos

- **Personal:** el administrador puede agregar, editar o dar de baja personas. La baja es lógica y conserva el historial. También se registran capacitaciones y vencimientos.
- **Equipos:** permite ordenar y filtrar por vigencia, editar la ficha y registrar calibraciones, verificaciones o mantenimientos.
- **Documentos:** registra código, versión, vigencia, responsable y vínculo al documento.
- **Configuración:** el administrador mantiene las opciones de los menús desplegables sin editar código.
- **Auditoría:** muestra los cambios y responsables para mantener la trazabilidad.

## 8. Permisos

- **Administrador:** acceso total a muestras, ensayos, personal, equipos, configuración, auditoría, informes y backups. No puede modificar datos crudos existentes.
- **Responsable del laboratorio:** puede editar y eliminar muestras, revisar ensayos y operar según sus permisos.
- **Analista:** carga muestras, ejecuta ensayos y agrega nuevas secuencias de datos según sus permisos.
- **Consulta:** acceso de lectura a las vistas habilitadas.

## 9. Uso desde el teléfono

- Usar el botón de menú del encabezado para cambiar de sección.
- Abrir las tarjetas solamente cuando haga falta para mantener la pantalla compacta.
- En formularios largos, los botones Guardar y Cancelar permanecen accesibles al pie.
- Las listas de muestras se convierten en tarjetas; las tablas administrativas extensas admiten desplazamiento horizontal controlado.
- Si el navegador conserva una versión anterior, recargar la página una vez.

## 10. Flujo recomendado

1. Crear la muestra y asignar responsable.
2. Ejecutar los ensayos y agregar datos en secuencias.
3. Enviar a revisión individualmente o en lote.
4. Aprobar, observar o marcar No Ensayado.
5. Descargar el QF-04 y validar el resumen con su QR.
6. Exportar backups periódicos desde Datos crudos.
