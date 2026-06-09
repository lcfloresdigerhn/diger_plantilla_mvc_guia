# 8. Git y flujo de trabajo

## Qué NUNCA se versiona

El `.gitignore` (raíz de este repo y el que genera `New-MvcProject.ps1`) ya cubre:

```
*.secret.config        ← secretos (JwtKey, credenciales)
appSettings.secret.config
connectionStrings.secret.config
bin/  obj/  packages/  .vs/  *.user  *.suo
```

- **Nunca** subas `*.secret.config`. Versiona solo `*.secret.config.example` con valores ficticios.
- Si pruebas la plantilla generando un proyecto **dentro** de este repo, ignóralo o (mejor)
  genéralo **fuera** con `-OutputPath ..\MiApp`.

## Flujo recomendado (proyecto generado)

```powershell
git checkout main; git pull
git checkout -b feature/<ID>-slug      # una rama por tarea/ticket
# ...trabajas, commits pequeños y claros...
git push -u origin feature/<ID>-slug
# abrir PR a main; en el cuerpo: "Closes #N" para cerrar el issue
```

- **Una rama por tarea**: `feature/<ID>-slug` (ej. `feature/PROD-01-listado`).
- **PR a `main`**; no mergees tu propio PR sin revisar.
- Configura tu identidad para commits limpios:
  `git config user.name "Tu Nombre"` y `git config user.email "tu@correo"`.

## Sobre este repo (la plantilla)

Es un **generador + guía**, no una app. Si editas los scripts o el wiki:
- Mantén los `.ps1` funcionando (no se compilan, pero pruébalos generando un proyecto desechable).
- Si cambias comportamiento o convenciones, **actualiza el wiki**:
  [10-mantener-el-wiki.md](10-mantener-el-wiki.md).
