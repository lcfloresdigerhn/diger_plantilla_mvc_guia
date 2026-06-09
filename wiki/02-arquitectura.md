# 2. Arquitectura

## Stack

| Capa | Tecnología |
|---|---|
| Web | ASP.NET **MVC 5** |
| Runtime | **.NET Framework 4.8** |
| ORM | **Entity Framework 6** Database-First (`.edmx`) |
| BD | **SQL Server** |
| Front | Razor (`.cshtml`) + jQuery/AJAX + bundles CSS/JS |
| Host dev | **IIS Express** (F5 en Visual Studio) |

> Es MVC5 / EF6, **no** ASP.NET Core. El `.csproj` es estilo clásico con `packages.config`.

## Qué genera `New-MvcProject.ps1`

```
MiApp/
├─ MiApp.sln
└─ MiApp/
   ├─ App_Start/
   │  ├─ RouteConfig.cs    ← rutas {controller}/{action}/{id}
   │  ├─ FilterConfig.cs   ← filtros globales (HandleError)
   │  └─ BundleConfig.cs   ← agrupado de CSS/JS
   ├─ Controllers/
   │  ├─ BaseController.cs  ← ValidaSesion() + ModoDesarrollo  (lo heredan todos)
   │  └─ HomeController.cs  ← ejemplo
   ├─ Models/               ← aquí va el .edmx de EF (lo agregas tú en VS)
   ├─ Views/
   │  ├─ _ViewStart.cshtml      ← fija el layout
   │  ├─ Shared/_Layout.cshtml  ← marco común (navbar/footer, Bootstrap por CDN)
   │  └─ Home/Index.cshtml
   ├─ Content/site.css      ← estilos propios
   ├─ Scripts/              ← JS propio
   ├─ Global.asax(.cs)      ← arranque (registra rutas/bundles/filtros)
   └─ Web.config            ← conexión SQL + ModoDesarrollo + bindingRedirects
```

`Add-MvcModule.ps1` agrega un **segundo proyecto** hermano que referencia al principal
y cuyo `HomeController` hereda su `BaseController` → [07-modulos.md](07-modulos.md).

## Flujo de un request

```
Navegador → Ruta (RouteConfig) → Controller (hereda BaseController)
  → ValidaSesion()  (sesión real, o bypass si ModoDesarrollo=true)
  → acción GET:     lee con Fn... → return View(modelo)        → HTML
  → acción Async... (POST): escribe con Sp... → return Json({estado,mensaje,data})
Vista (Razor) → $.post/app.ajax al endpoint Async → SP → JSON → muestra alerta
```

## Capas y responsabilidades

- **Controller** = orquesta: valida sesión, llama datos, devuelve vista o JSON. Hereda `BaseController`.
- **BaseController** = punto único de sesión/`ModoDesarrollo`. Lo reutilizan controllers y módulos.
- **Datos** = lectura con `Fn...`, escritura con `Sp...` (en SQL). Se llaman por EF (`new MiAppEntities()`) o ADO.NET.
- **Vistas** = HTML Razor con componentes CSS; el `_Layout` pone navbar/footer y secciones de scripts.

Convenciones en [03-convenciones.md](03-convenciones.md). El ciclo concreto para crear
una pantalla está en [06-agregar-pantalla.md](06-agregar-pantalla.md).
