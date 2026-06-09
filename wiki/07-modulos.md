# 7. Módulos (proyecto aparte enlazado)

## ¿Necesito un módulo? (casi siempre NO)

| Quiero agregar… | ¿Otro proyecto? |
|---|---|
| Página, componente, estilo, JS, tabla, SP | **No** — va dentro del proyecto actual |
| Lógica/seguridad compartida por todas las apps | **No** — al `BaseController` del principal |
| Una app **independiente** que se publica/despliega aparte (su propio puerto/URL) pero reutiliza la sesión | **Sí → `Add-MvcModule.ps1`** |
| Un sistema nuevo sin relación con el actual | **Sí → `New-MvcProject.ps1`** |

**Regla práctica:** casi todo lo nuevo NO necesita módulo. Solo crea un módulo cuando la
parte deba ser una **aplicación separada** que aún comparte sesión y `BaseController`.

## Crear el módulo

```powershell
.\Add-MvcModule.ps1 -Name Inventario -SolutionPath ..\MiApp
```

Qué hace:
- Crea un proyecto MVC completo **hermano** del principal, dentro de la misma solución.
- Lo registra en el `.sln` (entrada + configuraciones).
- Agrega una `ProjectReference` al principal: el `HomeController` del módulo
  **hereda del `BaseController`** del principal (reutiliza `ValidaSesion`/`ModoDesarrollo`,
  **no** duplica el BaseController).
- Hereda la cadena de conexión y corre en su propio puerto IIS Express.

Parámetros: `-Name` (obligatorio), `-SolutionPath` (al `.sln` o su carpeta),
`-MainProject` (por defecto el primero del `.sln`), `-SqlServer`/`-Database` (se heredan
del principal), `-Port` (aleatorio 44300–44399).

## Después de crearlo (en Visual Studio)

1. Recarga la solución (o ciérrala y ábrela).
2. Restaura NuGet si lo pide (comparte la carpeta `packages` con el principal).
3. Compila la solución.
4. Para correr el módulo: clic derecho en el proyecto del módulo →
   **Set as Startup Project** → **F5** (`https://localhost:<puerto>`).

## Producción

Se publican todos bajo **un mismo sitio IIS** como *Applications* (`/`, `/Inventario`, …).
Al compartir dominio + BD comparten la sesión (SSO). Detalle: `GUIA-DESARROLLO.md` §10.

## Compartir componentes entre proyectos

Un partial en `Views/Shared/` solo lo ve **su** proyecto. Para reutilizar entre módulos:
1. Heredar lógica/datos vía `BaseController` (ChildActions en el principal).
2. Copiar el partial/CSS/JS al módulo (lo más simple para vistas).
3. Ponerlo en el principal y consumirlo por la referencia que ya crea el script.
