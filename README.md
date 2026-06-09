# Plantilla MVC — Generador de proyectos y módulos

Generadores en PowerShell para crear proyectos **ASP.NET MVC 5** listos para trabajar,
con la estructura y convenciones del equipo ya armadas. En segundos tienes una solución
que compila, corre en IIS Express y se conecta a SQL Server.

**Stack:** ASP.NET MVC 5 · .NET Framework 4.8 · Entity Framework 6 (Database-First) ·
IIS Express + SQL Server.

> 📘 Esta es la guía de inicio rápido. Para el **manual completo de desarrollo**
> (crear páginas, vistas, EF, stored procedures, JWT, módulos, checklist), consulta
> **[GUIA-DESARROLLO.md](GUIA-DESARROLLO.md)**.
>
> 🤖 **¿Usas Claude Code?** Abre esta carpeta con Claude y pídele *"arranca un proyecto
> nuevo desde cero con esta plantilla"*. El archivo **[CLAUDE.md](CLAUDE.md)** es el
> playbook que Claude sigue para generar el proyecto, configurar la base de datos y
> construir pantallas que funcionan.

---

## ⚠️ Esto es una PLANTILLA — tu proyecto va en OTRO repo, no en este

Este repositorio es **solo la plantilla + la guía**. **No construyas tu proyecto aquí.**

**Para empezar tu proyecto:**

1. **Forkea o clona** este repo — es tu **base/guía** (scripts + documentación).
2. Ten **otro repo** (el de tu proyecto), o crea uno nuevo, para tu código.
3. Genera el proyecto con `New-MvcProject.ps1` **fuera** de esta carpeta
   (`-OutputPath ..\MiApp`) y versiónalo en **tu** repo.

```powershell
# 1) Clona/forkea esta plantilla (la guía)
git clone <URL-de-esta-plantilla> plantilla

# 2) Genera tu proyecto FUERA de la plantilla
cd plantilla
.\New-MvcProject.ps1 -Name MiApp -OutputPath ..\MiApp

# 3) Versiona MiApp en TU repo (no en este)
cd ..\MiApp
git init && git remote add origin <URL-de-TU-repo>
```

> **Resumen:** clona/forkea **esta plantilla** para tener la guía, pero tu código vive en
> **otro repo (el tuyo)** — **nunca en este**.

---

## ¿Qué hay en este repositorio?

| Archivo | Para qué sirve |
|---|---|
| **`New-MvcProject.ps1`** | Crea un **proyecto/portal nuevo** completo y autónomo (su propia `.sln`, `BaseController`, `HomeController`, vistas, `Web.config`, App_Start, bundles). |
| **`Add-MvcModule.ps1`** | Agrega un **módulo** (proyecto MVC independiente) a una solución existente. Referencia al proyecto principal y **hereda su `BaseController`** (reutiliza sesión/seguridad). |
| **`GUIA-DESARROLLO.md`** | Manual de desarrollo paso a paso para trabajar sobre cualquier proyecto generado. |
| **`CLAUDE.md`** | Playbook para Claude Code: de cero a una web funcionando (generar proyecto → configurar BD → construir pantallas). |
| **`wiki/`** | Wiki paso a paso para agentes LLM (varios `.md`): empezar de cero, arquitectura, BD, seguridad, agregar pantalla, módulos, git, troubleshooting. Ver [`wiki/README.md`](wiki/README.md). |
| **`Guia.pdf`** | Versión PDF de la guía. |

---

## Requisitos

- **Windows** con **PowerShell** (el que trae Windows funciona).
- **Visual Studio 2022** (Community o superior) con la carga de trabajo *ASP.NET y desarrollo web*.
- **SQL Server** (LocalDB, Express o una instancia de red) accesible desde tu equipo.
- Acceso a internet la primera vez (Visual Studio restaura los paquetes NuGet).

---

## Inicio rápido

### 1) Crear un proyecto nuevo

Desde la carpeta donde está el script:

```powershell
.\New-MvcProject.ps1 -Name MiApp
```

Con conexión a SQL Server personalizada:

```powershell
.\New-MvcProject.ps1 -Name MiApp -SqlServer "localhost\SQLEXPRESS" -Database "MiBD"
```

Esto crea la carpeta `MiApp\` con la solución `MiApp.sln` adentro.

**Parámetros de `New-MvcProject.ps1`:**

| Parámetro | Obligatorio | Por defecto | Descripción |
|---|---|---|---|
| `-Name` | ✅ | — | Nombre del proyecto y de la solución. |
| `-OutputPath` | ❌ | Carpeta actual | Dónde se crea la solución. |
| `-SqlServer` | ❌ | `localhost\SQLEXPRESS` | Instancia de SQL Server. |
| `-Database` | ❌ | = `Name` | Nombre de la base de datos. |
| `-Port` | ❌ | Aleatorio (44300–44399) | Puerto de IIS Express. |

### 2) Abrir y ejecutar

1. Abre `MiApp\MiApp.sln` en Visual Studio.
2. Deja que **restaure los paquetes NuGet** (o: clic derecho en la solución → *Restore NuGet Packages*).
3. Compila con **Ctrl+Shift+B**.
4. Presiona **F5** → la app abre en `https://localhost:<puerto>` (IIS Express).

> El proyecto arranca con `ModoDesarrollo = true` en `Web.config`: se omite el login para
> que puedas probar de inmediato. Cámbialo a `false` cuando integres autenticación real.

### 3) Agregar un módulo (opcional)

Cuando una parte del sistema deba ser una **app independiente** pero reutilizar la sesión
del principal, créala como módulo:

```powershell
.\Add-MvcModule.ps1 -Name Inventario -SolutionPath .\MiApp
```

**Parámetros de `Add-MvcModule.ps1`:**

| Parámetro | Obligatorio | Por defecto | Descripción |
|---|---|---|---|
| `-Name` | ✅ | — | Nombre del módulo/proyecto. |
| `-SolutionPath` | ❌ | Carpeta actual | Ruta al `.sln` o a la carpeta que lo contiene. |
| `-MainProject` | ❌ | Primer proyecto del `.sln` | Proyecto principal a referenciar. |
| `-SqlServer` | ❌ | Se hereda del principal | Instancia de SQL Server. |
| `-Database` | ❌ | Se hereda del principal | Base de datos. |
| `-Port` | ❌ | Aleatorio (44300–44399) | Puerto de IIS Express del módulo. |

Luego, en Visual Studio: recarga la solución → clic derecho en el módulo →
*Set as Startup Project* → **F5**.

---

## ¿Proyecto nuevo o módulo? Regla rápida

- **Casi todo lo nuevo** (páginas, componentes, estilos, JS, tablas, SPs) **NO necesita
  otro proyecto**: se agrega dentro del proyecto actual.
- Usa **`Add-MvcModule.ps1`** solo cuando la parte nueva deba publicarse/desplegarse aparte
  (su propio puerto/URL) pero **reutilizar la sesión y el `BaseController`** del principal.
- Usa **`New-MvcProject.ps1`** solo cuando arrancas un **sistema nuevo** sin relación con el actual.

Detalle completo en [GUIA-DESARROLLO.md → §2.1](GUIA-DESARROLLO.md).

---

## Estructura que genera

```
MiApp/
├─ MiApp.sln
└─ MiApp/
   ├─ App_Start/        ← RouteConfig · FilterConfig · BundleConfig
   ├─ Controllers/      ← BaseController (sesión/ModoDesarrollo) · HomeController
   ├─ Models/           ← modelo de datos (EF .edmx)
   ├─ Views/            ← _ViewStart · Shared/_Layout · Home/Index
   ├─ Content/          ← site.css
   ├─ Scripts/          ← JS propio
   ├─ Global.asax(.cs)
   └─ Web.config        ← conexión SQL + ModoDesarrollo
```

---

## Comandos de referencia

```powershell
# Crear un proyecto/portal nuevo
.\New-MvcProject.ps1 -Name MiApp -SqlServer "localhost\SQLEXPRESS" -Database "MiBD"

# Agregar un módulo a una solución existente
.\Add-MvcModule.ps1 -Name Inventario -SolutionPath .\MiApp

# Compilar desde línea de comandos (MSBuild de VS 2022)
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" .\MiApp\MiApp.sln /t:Build

# Ver la ayuda detallada de cada script
Get-Help .\New-MvcProject.ps1 -Full
Get-Help .\Add-MvcModule.ps1 -Full
```

---

## Solución de problemas

| Síntoma | Causa probable / Solución |
|---|---|
| *"Ya existe la carpeta '…'."* | Ya hay una carpeta con ese nombre. Elige otro `-Name` o borra la carpeta. |
| No se puede ejecutar el script (`.ps1` bloqueado) | Ejecuta en la sesión: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`. |
| Faltan referencias / no compila | Restaura los paquetes NuGet (clic derecho en la solución → *Restore NuGet Packages*) y recompila. |
| No conecta a la base de datos | Revisa `connectionStrings/DefaultConnection` en `Web.config` (servidor, BD, credenciales). |
| `Add-MvcModule` no encuentra el `.sln` | Pasa la ruta exacta: `-SolutionPath .\MiApp\MiApp.sln`. |

---

## Próximos pasos

Una vez creado el proyecto, sigue el manual para empezar a construir pantallas
de extremo a extremo (BD → EF → controller → vista → JS):

➡️ **[GUIA-DESARROLLO.md](GUIA-DESARROLLO.md)**
"# plantilla-mvc" 
"# plantilla-mvc" 
