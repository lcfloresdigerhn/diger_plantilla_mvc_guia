# Wiki — Plantilla MVC (para agentes LLM)

Wiki paso a paso para que **un agente (o una persona con Claude) nunca se pierda**
al arrancar un sistema web desde cero con esta plantilla. Cada archivo es corto,
ordenado y enlazado. Empieza por el índice y avanza en orden.

> ⚠️ **La fuente de verdad es el CÓDIGO y los scripts** (`New-MvcProject.ps1`,
> `Add-MvcModule.ps1`) más `GUIA-DESARROLLO.md`. Este wiki orienta y resume; si algo
> no coincide, manda el código. No lo trates como contrato.

## Índice

| # | Archivo | Para qué |
|---|---|---|
| 1 | [01-empezar-de-cero.md](01-empezar-de-cero.md) | El playbook completo: de carpeta vacía a web funcionando. **Empieza aquí.** |
| 2 | [02-arquitectura.md](02-arquitectura.md) | Stack, capas, estructura de carpetas, flujo de un request. |
| 3 | [03-convenciones.md](03-convenciones.md) | Nombres, `Fn`/`Sp`/`Async`, contrato AJAX, auditoría. |
| 4 | [04-base-de-datos.md](04-base-de-datos.md) | Crear la BD, `sqlcmd`, `Fn`/`Sp`, generar el `.edmx` (EF Database-First). |
| 5 | [05-seguridad-y-sesion.md](05-seguridad-y-sesion.md) | `ModoDesarrollo`, `BaseController.ValidaSesion`, JWT, secretos. |
| 6 | [06-agregar-pantalla.md](06-agregar-pantalla.md) | El ciclo de 4 capas: vista → GET → `Async` → `Sp`/`Fn`. |
| 7 | [07-modulos.md](07-modulos.md) | Cuándo y cómo agregar un módulo aparte (`Add-MvcModule.ps1`). |
| 8 | [08-git-y-flujo.md](08-git-y-flujo.md) | Ramas, commits, PR, qué nunca se versiona. |
| 9 | [09-troubleshooting.md](09-troubleshooting.md) | Errores comunes y su causa/solución. |
| 10 | [10-mantener-el-wiki.md](10-mantener-el-wiki.md) | **Protocolo para que el agente mantenga este wiki vivo.** |
| 11 | [11-probar-con-claude.md](11-probar-con-claude.md) | **Probar pantalla + endpoint + `Sp` con Claude** (SQL, build, app headless), sin abrir VS. |

## En una frase

Generador **ASP.NET MVC 5 · .NET 4.8 · EF6 (Database-First) · SQL Server · IIS Express**.
Flujo: `New-MvcProject.ps1` crea el proyecto → configuras la BD → desarrollas pantallas
con el patrón de 4 capas → (opcional) `Add-MvcModule.ps1` agrega apps hermanas.

## Cómo usar este wiki (agente)

1. Lee [01-empezar-de-cero.md](01-empezar-de-cero.md) y ejecuta sus pasos en orden.
2. Salta al archivo del tema que necesites (BD, pantalla, seguridad, módulo).
3. Si un paso es de Visual Studio (agregar/actualizar el `.edmx`), **deja todo listo y
   pídele el clic al usuario**: tú no puedes hacerlo por CLI.
4. **Cuando aprendas algo durable** (un error nuevo, una decisión, una convención),
   aplica el protocolo de [10-mantener-el-wiki.md](10-mantener-el-wiki.md): actualiza
   el `.md` que corresponda y deja el índice sincronizado.
