# 6. Agregar una pantalla

El ciclo que repites para cada pantalla. Patrón de 4 capas:
**vista (HTML) → acción GET → endpoint AJAX `Async` → `Sp`/`Fn`**.

```
[ Vista .cshtml ] --click--> [ main.js ] --AJAX--> [ Controller (endpoint Async) ]
       ^                                                      |
       |                                                      v
   render HTML <-- Model -- [ Controller (GET) ] <-- [ EF: db.Fn / db.Sp ] <--> [ SQL Server ]
```

## 1. BD: `Fn` (leer) + `Sp` (escribir)

Crea la tabla, la función y el SP; córrelos con `sqlcmd`; luego en VS *Update Model from
Database*. Plantillas en [04-base-de-datos.md](04-base-de-datos.md).

## 2. Controller (hereda `BaseController`)

```csharp
using System;
using System.Linq;
using System.Web.Mvc;
using System.Data.Entity.Core.Objects;   // ObjectParameter
using MiApp.Models;                       // namespace del .edmx

namespace MiApp.Controllers
{
    public class ProductoController : BaseController
    {
        private MiAppEntities db = new MiAppEntities();

        // Página (GET /Producto): LEE con Fn y devuelve la vista
        public ActionResult Index()
        {
            if (!ValidaSesion()) return Salir();
            var productos = db.FnProductoTodos().ToList();
            return View(productos);
        }

        // AJAX (POST /Producto/AsyncGuardar): ESCRIBE con Sp y devuelve JSON uniforme
        [HttpPost]
        public JsonResult AsyncGuardar(string nombre, decimal precio)
        {
            if (!ValidaSesion())
                return Json(new { estado = false, mensaje = "Sesión inválida.", data = (object)null });

            var respuesta = new ObjectParameter("Respuesta", typeof(int));
            var mensaje   = new ObjectParameter("Mensaje",   typeof(string));
            db.SpProductoGuardar(nombre, precio, /*IdUsuario*/ 1, respuesta, mensaje);

            int codigo = Convert.ToInt32(respuesta.Value);   // 1 / 0 / -1
            return Json(new {
                estado  = (codigo == 1),
                mensaje = Convert.ToString(mensaje.Value),
                data    = (codigo == 1) ? new { } : null
            });
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) db.Dispose();
            base.Dispose(disposing);
        }
    }
}
```

> La ruta `{controller}/{action}/{id}` ya existe: `GET /Producto` y `POST
> /Producto/AsyncGuardar` funcionan sin tocar `RouteConfig.cs`.

## 3. Vista

`Views/Producto/Index.cshtml` (recibe `List<FnProductoTodos_Result>`):

```html
@model IEnumerable<MiApp.Models.FnProductoTodos_Result>
@{ ViewBag.Title = "Productos"; }

<h1>Productos</h1>
<input id="nombre" placeholder="Nombre" />
<input id="precio" type="number" placeholder="Precio" />
<button id="btnGuardar" class="btn btn-primary">Guardar</button>

<table class="table">
    <thead><tr><th>Id</th><th>Nombre</th><th>Precio</th></tr></thead>
    <tbody>
        @foreach (var p in Model) { <tr><td>@p.Id</td><td>@p.Nombre</td><td>@p.Precio</td></tr> }
    </tbody>
</table>
```

## 4. JavaScript

`Scripts/main.js` (regístralo en `BundleConfig.cs` y renderiza el bundle en `_Layout`):

```javascript
$(function () {
    $("#btnGuardar").on("click", function () {
        $.post("/Producto/AsyncGuardar",
            { nombre: $("#nombre").val(), precio: $("#precio").val() },
            function (r) {                 // contrato { estado, mensaje, data }
                if (r.estado) { alert(r.mensaje); location.reload(); }
                else          { alert("Error: " + r.mensaje); }
            });
    });
});
```

## 5. Menú y prueba

Agrega el enlace en `_Layout` (o tu partial de menú):
```html
<li><a href="@Url.Action("Index", "Producto")">Productos</a></li>
```

Corre con `ModoDesarrollo=true`, entra a `/Producto`, guarda uno y verifica que aparece.

## Checklist

1. [ ] `Sp`/`Fn` en `db/` → correr con `sqlcmd` → *Update Model*.
2. [ ] Acción GET + vista `.cshtml` con `@model`.
3. [ ] Acción `Async` (POST) + JS con `$.post`/`app.ajax`.
4. [ ] Archivos nuevos registrados en el `.csproj` (VS lo hace al agregarlos desde el explorador).
5. [ ] Enlace en el menú.
6. [ ] Branch + commit → [08-git-y-flujo.md](08-git-y-flujo.md).

Ejemplo extendido (con validaciones y `app.ajax`): `GUIA-DESARROLLO.md` §11.

## Probarla con Claude (sin abrir VS)

Verifica capa por capa —SQL con `sqlcmd`, build con `MvcBuildViews=true`, y la app headless
con IIS Express pegándole al endpoint—: [11-probar-con-claude.md](11-probar-con-claude.md).
