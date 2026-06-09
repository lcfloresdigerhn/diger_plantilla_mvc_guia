# 3. Convenciones

Para que cualquiera (o cualquier agente) lea el código sin contexto. Son
**recomendaciones de equipo**: la plantilla compila con cualquier convención, pero sé
**consistente**. Detalle en `GUIA-DESARROLLO.md` §3.

## Nombres

| Objeto | Patrón | Ejemplo |
|---|---|---|
| Tabla | `Entidad` / `EntidadRelacion` | `Producto`, `ProductoCategoria` |
| Columna FK | `Ref<Entidad>Id` | `RefCategoriaId` |
| Función SQL (LEE) | `Fn...` | `FnProductoTodos` |
| Procedimiento (ESCRIBE) | `Sp...` | `SpProductoGuardar` |
| Acción controller AJAX | `Async...` (POST) | `AsyncGuardar` |
| CSS propio | prefijo del proyecto | `mi-card`, `mi-btn` |

- **PascalCase** en BD, C# y vistas.
- Primera columna `Id INT` PK auto-increment.
- Auditoría en toda tabla transaccional: `IdUsuario INT` + `FechaRegistro DATETIME`.

## Contrato AJAX (único en todo el proyecto)

Todo endpoint `Async...` responde el **mismo** JSON:

```json
{ "estado": true, "mensaje": "texto", "data": { } }
```

El cliente lee `estado` para decidir, `mensaje` para mostrar y `data` para los datos.
**Nunca** devuelvas formas distintas: rompe el contrato y confunde al front.

## SQL

- Todo `Sp` de escritura: `SET NOCOUNT ON;` + `BEGIN TRY/CATCH`. Si toca 2+ tablas, `BEGIN TRAN`.
- Salida uniforme recomendada: `@Respuesta INT` (**1** éxito · **0** validación · **-1** excepción)
  + `@Mensaje VARCHAR(MAX)`.
- Catálogos de estado como tablas (`Estado*`) con FK, no como strings sueltos.
- Scripts **idempotentes**: `IF NOT EXISTS`, `CREATE OR ALTER`.

## Regla de oro de las capas

- **GET de página** → `Fn...` (lectura) + `return View(datos)`.
- **`Async...` (AJAX, POST)** → `Sp...` (escritura) + `return Json({estado,mensaje,data})`.
- **JS** → `$.post`/`app.ajax` al endpoint `Async`, lee el contrato.

## Seguridad de datos

- No concatenar SQL ni HTML crudo. EF parametriza; los `Sp` usan parámetros tipados.
- Nunca confíes en IDs del cliente para autorizar: usa los del lado servidor (sesión).
- Secretos fuera del repo → [05-seguridad-y-sesion.md](05-seguridad-y-sesion.md).
