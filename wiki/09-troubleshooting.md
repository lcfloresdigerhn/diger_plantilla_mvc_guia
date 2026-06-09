# 9. Troubleshooting

Errores comunes al usar la plantilla y el proyecto generado.

## Al generar / scripts

| Síntoma | Causa / Solución |
|---|---|
| `No se puede ejecutar el script (.ps1 bloqueado)` | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` y reintenta. |
| `Ya existe la carpeta '…'` | Elige otro `-Name` o borra la carpeta. |
| `Add-MvcModule` no encuentra el `.sln` | Pasa la ruta exacta: `-SolutionPath ..\MiApp\MiApp.sln`. |
| El `.sln` no se actualizó (formato inesperado) | Agrega el proyecto a mano en VS: clic derecho en la solución → Add → Existing Project. |

## Al compilar / NuGet

| Síntoma | Causa / Solución |
|---|---|
| Faltan referencias / no compila | Restaura NuGet (clic derecho en la solución → *Restore NuGet Packages*) y recompila. |
| Las vistas `.cshtml` no se validan en build | Normal: `MvcBuildViews=false`. Para cazar errores de Razor antes, compila con `MSBuild /p:MvcBuildViews=true`. |

## Base de datos / EF

| Síntoma | Causa / Solución |
|---|---|
| `CREATE INDEX … QUOTED_IDENTIFIER` en `sqlcmd` | Agrega `-I` al comando `sqlcmd`. |
| `:r … not found` en SSMS | Corre los `.sql` uno por uno, o usa `sqlcmd` con varios `-i`. |
| No conecta a la BD | Revisa `connectionStrings/DefaultConnection` en `Web.config` (servidor, BD, credenciales) y que la instancia SQL esté arriba. |
| Una columna/tabla/SP nuevo "no existe" en C# | Faltó **Update Model from Database** en el `.edmx`. Los objetos nuevos no son de EF hasta regenerar. |
| Un `Sp` que devuelve filas no genera clase `_Result` | **Model Browser → Function Imports** → "Returns a Collection of". |

## En ejecución

| Síntoma | Causa / Solución |
|---|---|
| La app no abre / error de config | Revisa `Web.config`; si usas `configSource`, que exista el `*.secret.config` referenciado. |
| Una ruta da 404 | La acción/controller no existe aún, o el nombre no coincide con la carpeta de vistas. |
| Entras sin pedir login | `ModoDesarrollo=true` (esperado en dev). Cámbialo a `false` para login real → [05-seguridad-y-sesion.md](05-seguridad-y-sesion.md). |
| El AJAX no responde como esperas | Confirma el contrato `{ estado, mensaje, data }`; revisa la consola del navegador y que la acción sea `[HttpPost]`. |

¿Un error nuevo y reproducible que no está aquí? Agrégalo siguiendo
[10-mantener-el-wiki.md](10-mantener-el-wiki.md).
