# 1. Empezar de cero

Playbook completo: de una carpeta vacía a una web que corre. Sigue en orden.
Pregunta al usuario solo lo que no puedas deducir (nombre del proyecto, instancia SQL).

## Paso 0 — Requisitos (verificar, no asumir)

- **Windows + PowerShell**.
- **Visual Studio 2022** con la carga *ASP.NET y desarrollo web* (.NET Framework 4.8).
- **SQL Server** accesible (LocalDB / Express / red) + `sqlcmd` o SSMS.
- **No hay build/run por CLI** del proyecto generado: compilar/correr es **F5 en VS**.

Si un `.ps1` está bloqueado:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Paso 1 — Generar el proyecto

Desde la carpeta de este repo. Reemplaza nombre e instancia reales. Genera **fuera**
del repo de la plantilla para no mezclarlo (`-OutputPath ..\MiApp`):

```powershell
.\New-MvcProject.ps1 -Name MiApp -OutputPath ..\MiApp -SqlServer "localhost\SQLEXPRESS" -Database "MiBD"
```

Crea `MiApp\MiApp.sln`. Parámetros: `-Name` (obligatorio), `-OutputPath`, `-SqlServer`,
`-Database` (= `-Name`), `-Port` (aleatorio 44300–44399). Qué genera y por qué:
[02-arquitectura.md](02-arquitectura.md).

## Paso 2 — Base de datos

El `Web.config` apunta a `data source`/`initial catalog`, pero **la BD aún no existe**.
Créala y puébla con `sqlcmd`. Detalle, plantillas de tabla/`Fn`/`Sp` y cómo generar el
`.edmx`: [04-base-de-datos.md](04-base-de-datos.md).

```powershell
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -i .\db\00_crear_db.sql
```

## Paso 3 — Abrir, compilar, correr

1. Abre `MiApp\MiApp.sln` en Visual Studio.
2. Restaura NuGet (clic derecho en la solución → *Restore NuGet Packages*).
3. Compila (**Ctrl+Shift+B**).
4. **F5** → `https://localhost:<puerto>` (IIS Express). Con `ModoDesarrollo=true` entras
   sin login como "Desarrollador" → [05-seguridad-y-sesion.md](05-seguridad-y-sesion.md).

## Paso 4 — Construir la primera pantalla

Aplica el ciclo de 4 capas (vista → GET → `Async` → `Sp`/`Fn`):
[06-agregar-pantalla.md](06-agregar-pantalla.md). Convenciones de nombres:
[03-convenciones.md](03-convenciones.md).

## Paso 5 — (Opcional) Módulo aparte

Solo si una parte debe publicarse aparte pero reutilizar la sesión:
[07-modulos.md](07-modulos.md).

## Si algo falla

Errores comunes y su solución: [09-troubleshooting.md](09-troubleshooting.md).

---

**Checklist rápido**

- [ ] Proyecto generado (`New-MvcProject.ps1`).
- [ ] BD creada + tablas/`Fn`/`Sp` corridos con `sqlcmd`.
- [ ] `.edmx` generado/actualizado en VS (paso manual).
- [ ] NuGet restaurado, compila, F5 abre la home.
- [ ] Primera pantalla con el patrón de 4 capas.
