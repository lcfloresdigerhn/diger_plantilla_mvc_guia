# 4. Base de datos

EF es **Database-First**: primero existe la BD, luego EF genera las clases desde el `.edmx`.
El `Web.config` generado usa `integrated security=True` contra el `data source`/`initial
catalog` que pasaste, pero **la BD no se crea sola**.

## Paso 1 — Crear la BD y las tablas (`sqlcmd`)

Escribe scripts **idempotentes** en una carpeta `db/`. Ejemplo `db/00_crear_db.sql`:

```sql
IF DB_ID('MiBD') IS NULL CREATE DATABASE MiBD;
GO
USE MiBD;
GO
IF OBJECT_ID('dbo.Producto') IS NULL
CREATE TABLE Producto (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    Nombre        VARCHAR(100)  NOT NULL,
    Precio        DECIMAL(18,2) NOT NULL,
    Estado        INT NOT NULL DEFAULT 1,
    IdUsuario     INT NOT NULL,
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE()
);
GO
```

Córrelo:
```powershell
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -i .\db\00_crear_db.sql
```
- `-E` = autenticación integrada (Windows). Para SQL auth: `-U usuario -P clave`.
- `-I` = `QUOTED_IDENTIFIER ON` (evita el error al crear índices).
- `-b` = aborta al primer error (te muestra el fallo en vez de seguir).
- Varios scripts en orden: repite `-i` (`-i 00_... -i 01_... -i 02_...`).

## Paso 2 — Lectura `Fn`, escritura `Sp`

**Leer** con función con valor de tabla:
```sql
CREATE OR ALTER FUNCTION FnProductoTodos () RETURNS TABLE AS
RETURN SELECT Id, Nombre, Precio FROM Producto WHERE Estado = 1;
GO
```

**Escribir** con procedimiento (patrón `@Respuesta`/`@Mensaje`):
```sql
CREATE OR ALTER PROCEDURE SpProductoGuardar
    @Nombre VARCHAR(100), @Precio DECIMAL(18,2), @IdUsuario INT,
    @Respuesta INT OUTPUT, @Mensaje VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF (@Nombre IS NULL OR LEN(@Nombre) = 0)
        BEGIN SET @Respuesta = 0; SET @Mensaje = 'El nombre es obligatorio.'; RETURN; END

        INSERT INTO Producto (Nombre, Precio, Estado, IdUsuario, FechaRegistro)
        VALUES (@Nombre, @Precio, 1, @IdUsuario, GETDATE());

        SET @Respuesta = 1; SET @Mensaje = 'Guardado correctamente.';
    END TRY
    BEGIN CATCH
        SET @Respuesta = -1; SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO
```

## Paso 3 — Generar el modelo EF (en Visual Studio) ⚠️ paso manual

Esto **no se puede hacer por CLI**. Deja todo listo (tablas/`Fn`/`Sp` ya corridos) y
pídele al usuario:

1. Clic derecho en `Models` → **Add → New Item → ADO.NET Entity Data Model**.
2. **EF Designer from database** (Database-First).
3. Selecciona la conexión a tu SQL Server.
4. Marca **Tablas, Vistas, Funciones y Procedimientos** que necesites → Finish.
5. EF genera el `.edmx`, el `DbContext` (`MiAppEntities`) y las clases
   (`Fn*_Result`, `Sp*_Result`).

> **Tras CUALQUIER cambio de esquema** (nueva tabla/`Fn`/`Sp`): abre el `.edmx` →
> **Update Model from Database**. Si no lo haces, las columnas/objetos nuevos **no**
> existen como propiedades/métodos de EF.

Si un SP devuelve filas y no te genera la clase `_Result`: **Model Browser → Function
Imports** → "Returns a Collection of".

## Paso 4 — Usar el modelo desde un controller

```csharp
public class ProductoController : BaseController
{
    private MiAppEntities db = new MiAppEntities();

    public ActionResult Index()
    {
        if (!ValidaSesion()) return Salir();
        var lista = db.FnProductoTodos().ToList();   // LEER
        return View(lista);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) db.Dispose();
        base.Dispose(disposing);
    }
}
```

Llamar un `Sp` con parámetros de salida (`ObjectParameter`) y el ciclo completo:
[06-agregar-pantalla.md](06-agregar-pantalla.md). Cadena de conexión EF con metadatos:
`GUIA-DESARROLLO.md` §7.1.
