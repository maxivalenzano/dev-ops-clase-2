# 🚀 2026-09-13: Gobernanza en CD con Quality Gates, GitHub Deployments API y Troubleshooting de YAML

**Fecha**: 2026-09-13  
**Hito**: Implementación de compuertas de calidad manuales (*Quality Gates / Manual Approvals*) en Azure DevOps Environments, integración con la API de GitHub Deployments (`production`), diagnóstico y resolución del error sintáctico de YAML (*Informational Run*) y refinamiento minimalista de la portada del repositorio.

---

## 🎯 Objetivos de la sesión

1. **Gobernanza y Control de Cambios**: Pasar de un modelo de *Continuous Deployment* (despliegue automático y ciego a producción) a *Continuous Delivery* formal, requiriendo aprobación humana explícita antes de desplegar en la VM de producción.
2. **Evitar Deadlocks en Entornos Individuales**: Comprender y configurar adecuadamente la política de autoaprobación (*"Allow approvers to approve their own runs"*) en Azure DevOps.
3. **Observabilidad del Ciclo de Vida del Entorno**: Conectar el pipeline con la API REST de **GitHub Deployments** para registrar el estado activo del entorno `production` directamente en GitHub.
4. **Troubleshooting de YAML**: Diagnosticar y solucionar el error de *Informational Run* generado por colisiones de indentación en scripts bash con bloques heredoc JSON.
5. **Presentación Profesional**: Ajustar la visibilidad de Releases, Packages y Deployments en GitHub, aplicando una estética minimalista sin sobrecarga de información.

---

## 🛡️ 1. De Continuous Deployment a Continuous Delivery: Quality Gates en Azure DevOps

### Concepto Teórico
- **Continuous Deployment**: Todo cambio que supera los tests automatizados se despliega inmediatamente en producción sin intervención humana.
- **Continuous Delivery**: El software siempre está en un estado desplegable, pero el pase a producción está sujeto a una decisión de negocio, ventana de mantenimiento o compuerta de gobernanza (*Quality Gate*).

Para un entorno de producción o de laboratorio avanzado, el despliegue automático indiscriminado elimina la posibilidad de coordinar ventanas de mantenimiento o realizar chequeos previos.

### Implementación en Azure DevOps
En lugar de depender de scripts o pausas artificiales, Azure DevOps delega el control de aprobaciones a los **Environments**:

1. Navegación a **Pipelines** > **Environments** > `devops-vm-env`.
2. Acceso a **Approvals and checks** > **+ Add check** > **Approvals**.
3. **Configuración de Aprobadores**:
   - **Approvers**: `maxivalenzano` (usuario responsable).
   - **Instructions to approvers**: *"Validar que los smoke tests hayan pasado y que la ventana de mantenimiento esté habilitada."*
   - **Timeout**: 30 días.

```
┌─────────────────────────────────────────────────────────────┐
│                    Stage 1: Versioning                      │
│        (Calcula SemVer tag analizando Conventional Commits) │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       Stage 2: CI                           │
│        (Build .NET 10, Vite bundle, Docker images a ACR)    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 🛑 QUALITY GATE (Approval)                  │
│       ¿Aprobado por maxivalenzano en devops-vm-env?         │
│          [ Yes: Desplegar ]       [ No: Abortar ]           │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Aprobado)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       Stage 3: CD                           │
│   (Pull ACR -> docker compose up -d -> Nginx reload -> cURL)│
└─────────────────────────────────────────────────────────────┘
```

### ⚠️ El Hallazgo Crítico: Autoaprobación (*Allow approvers to approve their own runs*)
En esquemas corporativos estrictos, las normativas (como SOX o ISO 27001) exigen **Segregación de Funciones (Separation of Duties - SoD)**: la persona que escribe o hace commit del código *no puede* ser quien apruebe el despliegue a producción.

Sin embargo, en laboratorios de desarrollo personal o equipos unipersonales:
* Si se desmarca la opción **"Allow approvers to approve their own runs"**, Azure DevOps detecta que quien disparó el build es el mismo aprobador configurado.
* El sistema **bloquea la aprobación** para ese usuario y entra en un **deadlock infinito** esperando un segundo aprobador que físicamente no existe.
* **Solución**: Mantener siempre tildado el checkbox `[x] Allow approvers to approve their own runs` para validar el flujo sin requerir cuentas secundarias ficticias.

---

## 🌐 2. Integración con GitHub Deployments API

### ¿Por qué no basta con Git Tags o Releases?
- **Git Tag**: Sello estático en un commit puntual del historial.
- **GitHub Release**: Empaquetado formal de código fuente y binarios con notas de versión.
- **GitHub Deployment**: Registro dinámico que representa la presencia real de una versión corriendo en un ambiente físico o lógico (`production`, `staging`). Permite auditar en qué momento exacto se actualizó la infraestructura y cuál es la URL pública activa del servicio.

### Implementación vía REST API en Bash
En `azure-pipelines.yml`, una vez que los contenedores están corriendo y pasaron los *Smoke Tests* locales en la VM, se invocan dos endpoints de GitHub:

1. **Creación del Despliegue (`POST /repos/{owner}/{repo}/deployments`)**:
   ```bash
   DEP_RES=$(curl -s -X POST \
     -H "Authorization: Bearer ${GITHUB_PAT}" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/maxivalenzano/dev-ops-clase-2/deployments \
     -d "$(jq -n \
       --arg ref "devel" \
       --arg env "production" \
       --arg desc "Deploy automático desde Azure Pipelines" \
       '{ref: $ref, environment: $env, description: $desc, transient_environment: false, production_environment: true, auto_merge: false}')")
   
   DEPLOYMENT_ID=$(echo "$DEP_RES" | jq -r '.id // empty')
   ```

2. **Actualización de Estado (`POST /repos/{owner}/{repo}/deployments/{id}/statuses`)**:
   ```bash
   curl -s -X POST \
     -H "Authorization: Bearer ${GITHUB_PAT}" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/maxivalenzano/dev-ops-clase-2/deployments/${DEPLOYMENT_ID}/statuses" \
     -d "$(jq -n \
       --arg state "success" \
       --arg target_url "http://68.211.137.116" \
       --arg desc "Desplegado exitosamente en VM Azure vía Azure Pipelines" \
       '{state: $state, target_url: $target_url, description: $desc, environment_url: $target_url}')"
   ```

Esto habilita de inmediato en GitHub la tarjeta de **Environments -> production (Active)** en el lateral derecho del repositorio, con acceso directo a `http://68.211.137.116`.

---

## 🛠️ 3. Troubleshooting: El Incidente del "Informational Run" en Azure DevOps

### Síntoma
Al subir los cambios del pipeline con el nuevo paso de despliegue a GitHub, la ejecución en Azure Pipelines falló antes de comenzar, mostrando el mensaje de alerta:
> *"This is an informational run. There was a YAML error preventing Azure Pipelines from determining if the pipeline should run. If you expected this pipeline to run, please validate your YAML."*

### Diagnóstico de Causa Raíz
El error fue provocado por el formato del script Bash dentro del archivo `azure-pipelines.yml`:
- Se había utilizado un bloque multilínea de Bash con un *heredoc* (`cat <<EOF`) para construir el JSON del payload.
- Al escribir el JSON con llaves `{` o delimitadores empezando en la columna 1 o con tabulaciones/espaciados inconsistentes, el parser escalar de YAML (`bash: |`) interpretó que el bloque de texto había finalizado prematuramente.
- Para el motor de Azure Pipelines, el archivo YAML contenía una violación estructural de indentación que invalidaba el grafo completo del pipeline.

### Solución Técnica Definitiva
Se eliminaron por completo los bloques heredoc (`cat <<EOF`) dentro de las tareas de script y se reemplazaron por construcciones robustas con `jq -n` con flags `--arg`:
1. `jq` garantiza el escape automático y seguro de comillas, caracteres especiales y saltos de línea.
2. El script se mantiene estrictamente indentado dentro de la jerarquía de 12 espacios requerida por el step de YAML.
3. El pipeline volvió a compilarse y validarse instantáneamente sin errores de sintaxis.

---

## 🎨 4. Curaduría y Minimalismo en GitHub

Siguiendo el principio de diseño *"menos es más"*:
- Se desmarcaron tags redundantes en la sección **About** para no sobrecargar visualmente al visitante.
- Se mantuvieron los tópicos esenciales que definen las competencias técnicas del proyecto: `devops`, `azure-devops`, `docker-compose`, `podman`, `dotnet10`, `react18`, `nginx`.
- La portada del repositorio ahora expone en un solo golpe de vista:
  - **Releases**: Última versión SemVer oficial (`v2.3.1`) con su changelog.
  - **Packages**: Contenedores publicados en GHCR (`backend` y `frontend`).
  - **Deployments**: Estado activo del entorno `production` en la VM de Azure.

---

## 💡 Lecciones Aprendidas

1. **La infraestructura como código y los pipelines son código vivo**: Los scripts incrustados en YAML deben cuidarse con el mismo rigor que el código fuente; usar generadores de JSON (`jq`) previene fallas silenciosas de parsing.
2. **Gobernanza adaptada al contexto**: Los Quality Gates en los Environments de Azure DevOps son la herramienta nativa estándar para implementar *Continuous Delivery* sin ensuciar los scripts con lógica condicional de aprobación.
3. **Visibilidad completa (Single Pane of Glass)**: Unificar Azure DevOps con la API de GitHub permite que cualquier miembro del equipo (o reclutador/auditor) consulte el estado real del despliegue sin necesidad de tener credenciales de acceso a la nube ni al servidor.
