# 5. Seguridad y sesión

Punto central: `Controllers/BaseController.cs` (lo genera `New-MvcProject.ps1`).
**Fuente de verdad: ese código.** Profundidad en `GUIA-DESARROLLO.md` §9.

## ModoDesarrollo

- `Web.config` → `<add key="ModoDesarrollo" value="true" />`.
- **`true`**: `ValidaSesion()` **siempre pasa**; entras como "Desarrollador" sin login.
  Sirve para probar pantallas de inmediato.
- **`false`**: login real (debes implementar la validación de sesión/JWT).

El `BaseController` generado trae el patrón listo:
```csharp
public virtual bool ValidaSesion(int refPermisoId = 0)
{
    ViewBag.BaseUrl = ...;
    if (Estado == ControllerState.Desarrollo) { ViewBag.UsuarioActual = "Desarrollador"; return true; }
    // TODO: validar sesion real (cookies/token/BD) y permiso refPermisoId.
    return false;
}
```

Patrón estándar en cada acción:
```csharp
public ActionResult Index()
{
    if (!ValidaSesion()) return Salir();   // sin sesión → fuera
    return View();
}
```

## Login real con JWT (cuando lo necesites)

La plantilla deja el hueco; tú implementas en `BaseController` / una clase `Seguridad`:

- **Crear** un JWT HS256 firmado con `JwtKey` al hacer login; guárdalo en cookie
  (`Authorization`) y opcionalmente persiste la sesión en BD.
- **Validar** en cada request: leer la cookie, validar firma + expiración (y sesión en BD).
- Para blindar controllers completos, un atributo `[JwtAuthorize]` (AJAX→401,
  navegación→login) que se omite en `ModoDesarrollo`. Código de ejemplo en
  `GUIA-DESARROLLO.md` §9.2.
- Contraseñas: nunca en claro. Hash fuerte (PBKDF2-SHA256), guarda hash + salt.

Paquetes NuGet para JWT: `System.IdentityModel.Tokens.Jwt` y `Microsoft.IdentityModel.Tokens`.

## Secretos — NUNCA en el repo

`JwtKey`, cadenas con credenciales, API keys: **fuera del control de versiones**.

`Web.config` (sí se versiona; solo apunta al archivo externo):
```xml
<appSettings configSource="appSettings.secret.config" />
```

`appSettings.secret.config` (NO se versiona):
```xml
<appSettings>
  <add key="ModoDesarrollo" value="false" />
  <add key="JwtKey" value="CLAVE-LARGA-Y-ALEATORIA-MIN-32-CARACTERES" />
</appSettings>
```

- Versiona solo una plantilla `appSettings.secret.config.example` con valores ficticios.
- En `.gitignore`: `*.secret.config`.
- En el *Publish* de VS, excluye el archivo de secretos (no lo sobrescribas en el servidor).
- Si una key se filtró alguna vez, **rótala**: quitarla en un commit posterior no la borra
  del historial de git.

> El `.gitignore` de este repo ya ignora `*.secret.config`, `bin/`, `obj/`, `packages/`,
> `.vs/`. Ver [08-git-y-flujo.md](08-git-y-flujo.md).
