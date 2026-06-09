# 11. Probar una pantalla con Claude (sin abrir Visual Studio)

Crear pantalla + endpoint + `Sp` está en [06-agregar-pantalla.md](06-agregar-pantalla.md).
Aquí está **cómo Claude verifica que funciona** sin depender de F5 en VS, capa por capa,
de abajo hacia arriba. Si una capa falla, arregla y repite **esa** capa antes de subir.

> Honestidad: lo único que Claude **no** puede hacer por CLI es agregar/actualizar el
> `.edmx` (es de la IDE). Todo lo demás —SQL, build, correr la app y pegarle al endpoint—
> sí. No digas "probado" si no corriste realmente el paso.

---

## Capa 1 — SQL: que el `Sp`/`Fn` funcione solo

Antes de tocar C#, prueba el SQL directo con `sqlcmd`. Es lo más rápido y aísla errores.

```powershell
# 1) Crear/actualizar objetos
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -i .\db\00_crear_db.sql

# 2) Ejecutar el Sp con parámetros de salida y ver Respuesta/Mensaje
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -Q @"
USE MiBD;
DECLARE @r INT, @m VARCHAR(MAX);
EXEC SpProductoGuardar @Nombre='Prueba', @Precio=9.99, @IdUsuario=1,
     @Respuesta=@r OUTPUT, @Mensaje=@m OUTPUT;
SELECT Respuesta=@r, Mensaje=@m;
SELECT TOP 5 * FROM Producto ORDER BY Id DESC;
"@

# 3) Probar la función de lectura
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -Q "USE MiBD; SELECT * FROM dbo.FnProductoTodos();"
```

✅ Esperado: `Respuesta=1`, `Mensaje='Guardado correctamente.'` y la fila insertada.
Si falla aquí, el problema es SQL puro — no sigas a C#.

---

## Capa 2 — Build: que compile (incluido Razor)

El build normal **no** compila las vistas `.cshtml`. Para cazar errores de Razor, fuerza
`MvcBuildViews=true`. Restaura NuGet la primera vez.

```powershell
$msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"

# Restaurar paquetes (primera vez o si faltan refs)
& $msbuild ..\MiApp\MiApp.sln /t:Restore

# Compilar Y validar las vistas Razor
& $msbuild ..\MiApp\MiApp.sln /t:Build /p:Configuration=Debug /p:MvcBuildViews=true /v:m
```

✅ Esperado: `Build succeeded`. Errores típicos:
- Razor mal formado → solo aparece con `MvcBuildViews=true`.
- `db.Sp...`/`Fn...` no existe → faltó **Update Model from Database** en el `.edmx`
  (paso manual de VS; pídeselo al usuario) → [04-base-de-datos.md](04-base-de-datos.md).

> Ajusta la ruta de MSBuild a tu edición (`Community`/`Professional`/`Enterprise`).

---

## Capa 3 — App headless: correr y pegarle al endpoint

Con `ModoDesarrollo=true` no hay login, así que Claude puede llamar los endpoints
directamente. Levanta **IIS Express por línea de comandos** (no necesitas VS) y prueba.

```powershell
$iis = "C:\Program Files\IIS Express\iisexpress.exe"
$proj = (Resolve-Path ..\MiApp\MiApp).Path   # carpeta con el Web.config

# Arranca el sitio en segundo plano (puerto a tu gusto)
Start-Process $iis -ArgumentList "/path:`"$proj`"","/port:8080" -PassThru
Start-Sleep -Seconds 3
```

Luego ejercita las dos capas de la pantalla:

```powershell
# GET de página: debe devolver HTML 200 con tu contenido
$pagina = Invoke-WebRequest "http://localhost:8080/Producto" -UseBasicParsing
$pagina.StatusCode; ($pagina.Content -match "Productos")

# Endpoint AJAX (Async, POST): debe devolver el contrato { estado, mensaje, data }
$r = Invoke-RestMethod "http://localhost:8080/Producto/AsyncGuardar" -Method Post `
     -Body @{ nombre = "DesdeClaude"; precio = "12.50" }
$r            # -> estado, mensaje, data

# Confirma en BD que realmente persistió
sqlcmd -S "localhost\SQLEXPRESS" -E -b -I -Q "USE MiBD; SELECT TOP 1 * FROM Producto WHERE Nombre='DesdeClaude' ORDER BY Id DESC;"
```

✅ Esperado: GET `200` con tu texto; `r.estado = True` y `r.mensaje` de éxito; la fila en BD.

Detén IIS Express al terminar:
```powershell
Get-Process iisexpress -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

## Qué probar en cada caso

| Cambiaste… | Capas a verificar |
|---|---|
| Solo un `Sp`/`Fn` | Capa 1 (sqlcmd) |
| Controller / endpoint C# | Capa 2 (build) + Capa 3 (endpoint) |
| Una vista `.cshtml` | Capa 2 con `MvcBuildViews=true` + Capa 3 (GET y revisar el HTML) |
| JS del cliente | Capa 3 no lo cubre (no hay navegador); revisa el `.js` y deja la prueba visual al usuario, o usa la consola del navegador |

## Límites honestos

- **El `.edmx` (agregar / Update Model)** es manual en VS. Deja todo listo y pide el clic.
- **Pruebas visuales/JS en navegador** (estilos, eventos jQuery) no se cubren headless;
  para eso, F5 en VS o que el usuario lo revise.
- Si IIS Express no levanta: confirma que el proyecto **ya compiló** (Capa 2) y que el
  puerto esté libre. Errores comunes en [09-troubleshooting.md](09-troubleshooting.md).
