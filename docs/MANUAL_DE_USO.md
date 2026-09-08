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
2. Elegir una acción: enviar a revisión, aprobar, observar, marcar como No ensayado o anular.
3. Tocar **Aplicar**.

La acción afecta solamente los ensayos vigentes y compatibles con esa transición.

### Editar o eliminar

El administrador y el Responsable del laboratorio pueden editar una muestra. Al cambiar los ensayos asignados, los marcados se agregan y los desmarcados se archivan con trazabilidad. Al eliminar una muestra, también se archivan sus ensayos asociados y dejan de mostrarse sus datos crudos; la auditoría conserva el historial. Los datos crudos no se modifican ni se borran y continúan incluidos en el backup completo.

## 4. Ensayos

En **Ensayos** se puede ordenar y filtrar por estado, seleccionar varios y enviarlos juntos a revisión. Los estados finales permanecen fuera de la vista activa y se muestran al cambiar el filtro.

El circuito de estados es controlado:

1. Todo ensayo nuevo comienza **Pendiente**.
2. Al guardar la primera secuencia pasa automáticamente a **Datos cargados**. No puede volver a Pendiente mientras existan datos.
3. Desde **Datos cargados** se puede **Enviar a revisión**, quedando **Pendiente de revisión**.
4. En revisión se puede aprobar u observar. **Aprobado** queda bloqueado para todos salvo el administrador.
5. Al observar, el ensayo original queda **Observado** y el sistema crea automáticamente una nueva repetición **Pendiente**, con el mismo responsable y equipo.
6. **Anulado** y **No ensayado** son estados finales bloqueados. No existe N/A como estado de ensayo; N/A sigue disponible únicamente para campos o mediciones que no aplican.

El administrador puede cambiar el ensayo o su responsable y corregir registros finalizados. Ningún cambio administrativo altera los datos crudos ya almacenados.

Las unidades, el formulario y el equipo principal se completan según el catálogo. Los valores vacíos se consideran N/A y no participan de promedios ni niveles. En pH, el índice de diferencia y el cumplimiento se calculan automáticamente.

Cuando el resultado calculado es **No cumple**, el sistema crea una alerta trazable y envía un correo al responsable asignado y a todos los administradores activos. Si el proveedor de correo no está disponible, la alerta queda pendiente con el detalle del error para reintentarla.

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

- **Personal:** el administrador puede agregar personas y asignarles nombre de usuario, correo, contraseña provisoria, rol y permisos. Al editar una persona puede cambiar el usuario o correo y establecer una contraseña nueva; por seguridad, la contraseña actual nunca se muestra. La baja es lógica, bloquea el acceso y conserva el historial. Al reactivar a una persona se rehabilita su cuenta. También se registran capacitaciones y vencimientos.
- **Equipos:** permite ordenar y filtrar por vigencia, editar la ficha y registrar calibraciones, verificaciones o mantenimientos.
- **Documentos:** registra código, versión, vigencia, responsable y vínculo al documento.
- **Configuración:** el administrador mantiene las opciones de los menús desplegables y el catálogo maestro de ensayos sin editar código.
- **Auditoría:** muestra los cambios y responsables para mantener la trazabilidad.

### Agregar o modificar tipos de ensayo

1. Entrar a **Configuración** como administrador.
2. En **Catálogo de ensayos**, usar **Agregar ensayo** o buscar uno existente y tocar **Editar**.
3. Completar nombre, norma, método, formulario de medición, unidad por defecto, equipo principal y equipamiento requerido.
4. Mantenerlo **Activo** para que aparezca al asignar ensayos a muestras. Elegir **Inactivo** para retirarlo de nuevas asignaciones sin borrar su historial.

El tipo de cálculo determina cómo se obtiene el resultado, nivel y cumplimiento. Los datos crudos ya guardados no se modifican cuando cambia o se inactiva una definición del catálogo.

### Configurar los campos de cada formulario

1. Entrar a **Configuración > Catálogo de ensayos**.
2. Buscar el ensayo y tocar **Configurar formulario**.
3. Recorrer sus campos en el orden en que se mostrarán; usar **Agregar campo**, **Editar** o **Eliminar** según corresponda.
4. Para cada campo definir el texto visible, una clave interna única, tipo de dato, unidad, orden y condición:
   - **Obligatorio:** debe completarse para guardar la medición.
   - **Opcional:** puede quedar vacío y no interviene en cálculos.
   - **Fijo:** muestra el valor configurado y el usuario no puede cambiarlo.
5. El tipo **Lista de opciones** permite escribir las opciones disponibles, una por línea. Si se activa **Permitir que el usuario agregue texto**, también acepta un valor nuevo escrito por el analista y lo incorpora automáticamente a la lista para las cargas siguientes.
6. Guardar el campo. El cambio se aplica en la próxima apertura del formulario de carga.

Los campos numéricos aceptan únicamente números o N/A. Los datos crudos guardados continúan siendo inmutables aunque después se cambie el formulario.

### Configurar qué ensayos se marcan automáticamente

1. En **Configuración > Selección automática de ensayos**, elegir la norma o tipo de solicitud, por ejemplo **Ensayos de rutina**.
2. Marcar solamente los ensayos que deben aparecer seleccionados de manera predeterminada.
3. Tocar **Guardar selección automática**.

Al crear o editar una muestra, elegir esa norma aplica la selección configurada. Antes de guardar, el usuario puede marcar o desmarcar manualmente cualquier ensayo.

## 8. Permisos

- **Administrador:** acceso total a muestras, ensayos, personal, equipos, configuración, auditoría, informes y backups. No puede modificar datos crudos existentes.
- **Responsable del laboratorio:** puede editar y eliminar muestras, revisar ensayos y operar según sus permisos.
- **Analista:** carga muestras, ejecuta ensayos y agrega nuevas secuencias de datos según sus permisos.
- **Consulta:** acceso de lectura a las vistas habilitadas.

### Crear o modificar un acceso

1. Entrar a **Personal** como administrador.
2. Tocar **Agregar personal**, o **Editar y gestionar acceso** en una persona existente.
3. Completar un nombre de usuario único, correo y contraseña provisoria. En una cuenta existente, dejar la contraseña vacía conserva la actual; escribir otra la reemplaza.
4. Elegir rol, estado y permisos, y guardar.
5. La persona podrá ingresar inmediatamente con el nombre de usuario o con el correo y la contraseña asignada.

Las contraseñas se guardan cifradas en Supabase Auth y no forman parte de la tabla de Personal, los backups ni la auditoría. Si la persona la olvida, puede usar **Olvidé mi contraseña** con su usuario o correo.

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
4. Aprobar, observar, marcar No ensayado o anular. Al observar se crea sola la repetición pendiente.
5. Descargar el QF-04 y validar el resumen con su QR.
6. Exportar backups periódicos desde Datos crudos.
