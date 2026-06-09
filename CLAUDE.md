# CLAUDE.md

Guía para Claude Code (y para cualquier persona que use Claude) para arrancar un
sistema web **desde cero** con esta plantilla: generar el proyecto, configurar la
base de datos y construir pantallas que funcionan.

> **Este repo NO es una aplicación.** Es un **generador + guía**. Aquí no se compila
> nada: los scripts de PowerShell crean *otro* proyecto (en otra carpeta) que sí es la
> app. Tu trabajo es ejecutar los scripts y luego desarrollar dentro del proyecto generado.

---

## Qué hay en este repo

| Archivo | Para qué sirve |
|---|---|
| `New-MvcProject.ps1` | Genera un **proyecto/portal nuevo** completo y autónomo (su propia `.sln`, `BaseController` con `ValidaSesion`/`ModoDesarrollo`, `HomeController`, vistas, `Web.config`, App_Start, bundles, `.gitignore`). |
| `Add-MvcModule.ps1` | Agrega un **módulo** (proyecto MVC independiente) a una solución ya generada. Referencia al principal y **hereda su `BaseController`** (reutiliza sesión/seguridad). |
| `GUIA-DESARROLLO.md` | Manual de desarrollo paso a paso (páginas, vistas, EF, stored procedures, JWT, módulos, checklist). **Fuente de verdad para el "cómo".** |
| `wiki/` | **Wiki para agentes LLM**: varios `.md` cortos y paso a paso (empezar de cero, arquitectura, BD, seguridad, pantalla, módulos, git, troubleshooting). Empieza por [`wiki/README.md`](wiki/README.md). |
| `README.md` | Inicio rápido orientado a personas. |
| `Guia.pdf` | Versión PDF de la guía. |
| `CLAUDE.md` | Este archivo: el playbook que Claude ejecuta para llevar a alguien de cero a una web funcionando. |

**Stack que genera:** ASP.NET **MVC 5** · **.NET Framework 4.8** · **Entity Framework 6**
(Database-First) · **SQL Server** · IIS Express. **No es ASP.NET Core.**

---

## Playbook: de cero a una web funcionando

Sigue estos pasos en orden. Pregunta al usuario solo lo que no puedas deducir
(nombre del proyecto, instancia de SQL Server). Cada paso tiene su archivo detallado en
[`wiki/`](wiki/README.md) — ábrelo cuando necesites profundidad.

### Paso 0 — Requisitos (verificar, no asumir)

- **Windows + PowerShell** (el de Windows sirve).
- **Visual Studio 2022** con la carga *ASP.NET y desarrollo web* (.NET Framework 4.8).
- **SQL Server** accesible (LocalDB, Express o instancia de red) + SSMS o `sqlcmd`.
- No hay build por CLI: compilar/ejecutar es **F5 en Visual Studio** (IIS Express).

Si el script `.ps1` está bloqueado:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Paso 1 — Generar el proyecto

Desde la carpeta de este repo. Reemplaza `MiApp` por el nombre real y `-SqlServer`
por la instancia del usuario:

```powershell
.\New-MvcProject.ps1 -Name MiApp -SqlServer "localhost\SQLEXPRESS" -Database "MiBD"
```

Crea `MiApp\` con `MiApp.sln` adentro. Genera el proyecto **fuera** de este repo si no
quieres mezclarlo con la plantilla (`-OutputPath ..\MiApp`).

Parámetros: `-Name` (obligatorio), `-OutputPath` (carpeta destino), `-SqlServer`,
`-Database` (= `-Name` por defecto), `-Port` (aleatorio 44300–44399).

### Paso 2 — Configurar la base de datos

El `Web.config` generado usa `integrated security=True` contra `data source` y
`initial catalog` que pasaste. **La base aún no existe**: hay que crearla.

1. **Crear la BD y tablas.** Escribe un script SQL idempotente (`IF NOT EXISTS`,
   `CREATE OR ALTER`) y córrelo con `sqlcmd`. Plantilla mínima:

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

   ```powershell
   sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -i .\db\00_crear_db.sql
   ```
   - `-E` = autenticación integrada (Windows). Para SQL auth usa `-U usuario -P clave`.
   - `-I` evita el error `QUOTED_IDENTIFIER` al crear índices.
   - `-b` aborta en el primer error (útil para ver fallos).

2. **Lectura con `Fn...`, escritura con `Sp...`.** Convención del equipo: funciones
   con valor de tabla para leer, procedimientos para escribir (patrón `@Respuesta`
   INT + `@Mensaje` VARCHAR(MAX)). Ver `GUIA-DESARROLLO.md` §7–§8.

3. **Generar el modelo EF (Database-First)** en Visual Studio, una vez existan las
   tablas/SP/Fn: clic derecho en `Models` → *Add → New Item → ADO.NET Entity Data
   Model* → *EF Designer from database* → marca tablas/Fn/SP → Finish. Esto crea el
   `.edmx` y el `DbContext` (`MiAppEntities`). **Tras cada cambio de esquema: abrir el
   `.edmx` → *Update Model from Database*.** Claude no puede hacer este paso (es de la
   IDE): indícaselo al usuario claramente.

4. **Conexión EF con metadatos.** Al agregar el `.edmx`, EF crea una conexión
   `EntityClient` aparte (`name="MiAppEntities"`). Ver `GUIA-DESARROLLO.md` §7.1.

### Paso 3 — Secretos fuera del repo (cuando uses login real)

`ModoDesarrollo=true` (por defecto) **omite el login** para que pruebes pantallas ya.
Cuando integres autenticación real (JWT):

- Mueve secretos a archivos externos vía `configSource`/`file`:
  ```xml
  <appSettings configSource="appSettings.secret.config" />
  ```
  ```xml
  <!-- appSettings.secret.config (NO se versiona) -->
  <appSettings>
    <add key="ModoDesarrollo" value="false" />
    <add key="JwtKey" value="CLAVE-LARGA-Y-ALEATORIA-MIN-32-CARACTERES" />
  </appSettings>
  ```
- Versiona solo un `*.secret.config.example` con valores ficticios.
- `*.secret.config` debe estar en `.gitignore`. Detalle en `GUIA-DESARROLLO.md` §9.3.

### Paso 4 — Abrir, compilar y correr

1. Abre `MiApp\MiApp.sln` en Visual Studio.
2. Deja que restaure NuGet (o clic derecho en la solución → *Restore NuGet Packages*).
3. Compila (**Ctrl+Shift+B**).
4. **F5** → abre en `https://localhost:<puerto>` (IIS Express). Con `ModoDesarrollo=true`
   entras sin login como "Desarrollador".

### Paso 5 — Construir una pantalla (el ciclo que se repite)

Patrón de 4 capas: **vista (HTML) → acción GET → endpoint AJAX `Async` → `Sp`/`Fn`**.

```
[ Vista .cshtml ] --click--> [ main.js ] --AJAX--> [ Controller endpoint ]
       ^                                                    |
       |                                                    v
   render HTML <-- ViewBag/Model -- [ Controller ] <-- [ EF: db.Fn / db.Sp ] <--> [ SQL Server ]
```

1. **BD:** tabla + `Fn...` (leer) + `Sp...` (escribir) → correr con `sqlcmd` → *Update Model*.
2. **Controller** que hereda `BaseController`:
   - Acción de **página** (GET): `if (!ValidaSesion()) return Salir();` → `db.Fn...()` → `return View(datos)`.
   - Acción **AJAX** (`[HttpPost] AsyncGuardar`): `db.Sp...(...)` → `return Json(new { estado, mensaje, data })`.
3. **Vista** `Views/<Entidad>/Index.cshtml` con `@model ...`.
4. **JS** en `Scripts/main.js` (registrado en `BundleConfig.cs`): `$.post(url, datos, ...)`
   leyendo el contrato `{ estado, mensaje, data }`.
5. Enlaza la página en el menú (`_Layout` o un partial).

Ejemplo completo de extremo a extremo (Productos: listar + guardar) en
`GUIA-DESARROLLO.md` §11.

### Paso 6 — ¿Módulo aparte? (opcional)

Solo si la parte nueva debe **publicarse/desplegarse aparte** (su propio puerto/URL)
pero **reutilizar la sesión** del principal:

```powershell
.\Add-MvcModule.ps1 -Name Inventario -SolutionPath .\MiApp
```

Casi todo lo nuevo (páginas, componentes, estilos, JS, tablas, SPs) **NO** necesita
módulo: va dentro del proyecto actual.

---

## Convenciones (recomendadas, consistentes en todas las capas)

| Objeto | Patrón | Ejemplo |
|---|---|---|
| Tabla | `Entidad` / `EntidadRelacion` | `Producto`, `ProductoCategoria` |
| Columna FK | `Ref<Entidad>Id` | `RefCategoriaId` |
| Función SQL (lee) | `Fn...` | `FnProductoTodos` |
| Procedimiento (escribe) | `Sp...` | `SpProductoGuardar` |
| Método controller AJAX | `Async...` (POST) | `AsyncGuardar` |
| CSS propio | prefijo de proyecto | `mi-card`, `tu-btn`… |

- **PascalCase** en BD, C# y vistas. Primera columna `Id INT` PK auto-increment;
  auditoría `IdUsuario INT` + `FechaRegistro DATETIME` en cada tabla transaccional.
- **Contrato AJAX único** en todo el proyecto: `{ estado: bool, mensaje: string, data: object }`.
- SP de escritura: `SET NOCOUNT ON;` + `BEGIN TRY/CATCH`; salida `@Respuesta` (1 éxito /
  0 validación / -1 excepción) + `@Mensaje`.
- Scripts SQL **idempotentes**.

> Nada de esto es obligatorio para compilar: es convención de equipo. Si el proyecto ya
> usa otra, mantén la suya. Lo importante es ser **consistente**.

---

## Reglas para Claude al trabajar con esta plantilla

- **No inventes pasos de Visual Studio que puedas evitar, pero tampoco los ejecutes:**
  agregar el `.edmx` y *Update Model from Database* son de la IDE. Cuando un paso requiera
  VS, dilo explícitamente y deja el resto listo para que el usuario solo dé el clic.
- **No hay build/run por CLI** en el proyecto generado: la verificación final es F5 en VS.
  No prometas haber "probado" la app si no se ha corrido en VS.
- **Nunca pongas secretos en el código ni en archivos versionados.** `JwtKey`, cadenas con
  credenciales y API keys van en `*.secret.config` (en `.gitignore`).
- **Respeta el patrón de 4 capas y el contrato AJAX**: no devuelvas formas JSON distintas.
- **GET → `Fn` + `View`; `Async` → `Sp` + `Json`.** No mezcles lectura/escritura.
- Cuando generes el proyecto, hazlo **fuera de este repo** (o ignora la carpeta) para no
  versionar una app generada dentro de la plantilla.
- Para el "cómo" detallado, **lee `GUIA-DESARROLLO.md` y el [`wiki/`](wiki/README.md)** antes de improvisar.
- **Mantén el wiki vivo:** cuando aprendas algo durable (un error nuevo, una decisión, un
  cambio de comportamiento de los scripts), actualiza el `.md` del tema y sincroniza el
  índice, siguiendo [`wiki/10-mantener-el-wiki.md`](wiki/10-mantener-el-wiki.md). Si algo te
  costó descubrir, escríbelo ahí para que no le cueste al siguiente agente.

---

## Comandos de referencia

```powershell
# Crear un proyecto/portal nuevo
.\New-MvcProject.ps1 -Name MiApp -SqlServer "localhost\SQLEXPRESS" -Database "MiBD"

# Agregar un módulo a una solución existente
.\Add-MvcModule.ps1 -Name Inventario -SolutionPath .\MiApp

# Crear/poblar la base de datos
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -i .\db\00_crear_db.sql

# Compilar desde línea de comandos (MSBuild de VS 2022)
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" .\MiApp\MiApp.sln /t:Build

# Ayuda detallada de cada script
Get-Help .\New-MvcProject.ps1 -Full
Get-Help .\Add-MvcModule.ps1 -Full
```
