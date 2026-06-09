# 10. Mantener el wiki (protocolo para el agente)

Este wiki solo sirve si **se mantiene vivo**. Cuando trabajes con esta plantilla y
aprendas algo durable, **actualízalo en el mismo turno**, antes de cerrar la tarea.

## Cuándo actualizar (gatillos)

Actualiza el wiki cuando ocurra cualquiera de estos:

- **Un error nuevo y reproducible** con causa/solución → agrégalo a
  [09-troubleshooting.md](09-troubleshooting.md).
- **Una decisión o convención nueva** (nombres, contrato, estructura) →
  [03-convenciones.md](03-convenciones.md) o el archivo del tema.
- **Cambió el comportamiento de un script** (`New-MvcProject.ps1` / `Add-MvcModule.ps1`):
  nuevos parámetros, archivos que genera, rutas → [02-arquitectura.md](02-arquitectura.md) /
  [07-modulos.md](07-modulos.md).
- **Un paso del playbook cambió o faltaba** → [01-empezar-de-cero.md](01-empezar-de-cero.md).
- **Un paso manual de Visual Studio** que tropezó a alguien → el archivo del tema, marcado
  con ⚠️ y la frase exacta que el usuario debe seguir.

## Cómo actualizar (reglas)

1. **Una idea = un lugar.** No dupliques: pon el detalle en el archivo del tema y enlaza
   desde donde haga falta con `[texto](NN-archivo.md)`.
2. **Edita el archivo existente** antes de crear uno nuevo. Crea archivo nuevo solo si es
   un tema entero que no encaja en ninguno.
3. **Sincroniza el índice.** Si agregas/renombras un archivo, actualiza la tabla de
   [README.md](README.md) y los enlaces que apunten a él.
4. **Conciso y accionable.** Pasos imperativos, comandos copiables, sin relleno. Este wiki
   es para que un agente ejecute, no para leer prosa.
5. **No inventes.** Si no lo verificaste en el código/scripts o ejecutándolo, no lo
   escribas como hecho. Marca lo incierto.
6. **Respeta la jerarquía de verdad.** Código y scripts > `GUIA-DESARROLLO.md` > este wiki.
   Si el wiki contradice al código, corrige el wiki.
7. **No metas secretos** (claves, credenciales, rutas privadas) en ningún `.md`.

## Después de editar

- Relee tu cambio: ¿un agente sin contexto podría ejecutarlo sin perderse?
- Si el repo se versiona, incluye el cambio del wiki en el mismo commit/PR que el cambio
  que lo motivó (mensaje claro, p. ej. `docs(wiki): nuevo error de QUOTED_IDENTIFIER`).

> Regla de una línea: **si algo te costó descubrir, escríbelo aquí para que no le cueste al siguiente.**
