# 🚀 2026-09-12: Diseño e Implementación de CI/CD en Azure DevOps y Versionado Semántico

**Fecha**: 2026-09-12  
**Hito**: Implementación exitosa del pipeline de Integración Continua (CI) en **Azure DevOps Pipelines**, automatización de Versionado Semántico (SemVer `2.0.1`) mediante Conventional Commits, publicación de imágenes OCI en Azure Container Registry (ACR) y resolución de dificultades en el flujo de despliegue.

---

## 🎯 Objetivos de la sesión
- Desmitificar la automatización: construir el camino con control total (sin "magia negra"), entendiendo cada etapa del ciclo de vida DevOps.
- Diseñar un pipeline declarativo multi-stage (`azure-pipelines.yml`) que separe limpiamente las responsabilidades de **Integración Continua (CI)** y **Despliegue Continuo (CD)**.
- Implementar una estrategia de **Versionado Semántico (SemVer)** determinístico y automatizado basado en la convención de mensajes Git (**Conventional Commits**).
- Eliminar antipatrones de seguridad (evitar llaves SSH hardcodeadas o credenciales en texto plano) usando **Service Connections** en Azure DevOps.
- Registrar y documentar las dificultades técnicas encontradas durante la puesta en marcha para capitalizar el aprendizaje.

---

## 🏛️ Arquitectura del Pipeline Multi-Stage

```
 +-----------------------------------------------------------------------------------+
 |                             AZURE DEVOPS PIPELINE                                 |
 +-----------------------------------------------------------------------------------+
                                           |
                                           v
   [ STAGE 1: VERSIONING (SemVer) ] 
   - Analiza historial Git completo (fetchDepth: 0).
   - Parsea Conventional Commits (fix: -> PATCH, feat: -> MINOR, BREAKING -> MAJOR).
   - Exporta variable $(SEMVER_TAG) y renombra la corrida vía ##vso[build.updatebuildnumber].
                                           |
                                           v
   [ STAGE 2: CI - BUILD & CONTAINERIZE ]
   +---------------------------------------+---------------------------------------+
   |              BACKEND (.NET 10)        |          FRONTEND (REACT 18)          |
   | - Validación de compilación Release   | - Instalación limpia: npm ci          |
   | - Docker build (.NET Alpine)          | - Vite build estático                 |
   | - Tag: acr.../backend:$(SEMVER_TAG)   | - Docker build (Nginx SPA)            |
   |                                       | - Tag: acr.../frontend:$(SEMVER_TAG)  |
   +---------------------------------------+---------------------------------------+
                                           |
                                           v
   [ PUBLICACIÓN EN ACR ]
   - Push autenticado vía Service Connection (acrdevopsvalenzano-sc) a acrdevopsvalenzano.azurecr.io
                                           |
                                           v
   [ STAGE 3: CD - DEPLOY TO AZURE VM ]
   - Vinculado al Environment `devops-vm-env` para trazabilidad y auditoría.
   - Inyección del nuevo tag en variables dinámicas de compose.yaml (${IMAGE_TAG}).
   - Despliegue atómico con Docker Compose en la VM.
```

---

## 🛠️ Acciones Realizadas

1. **Parametrización de Contenedores**:
   - En `compose.yaml` se desacoplaron las versiones estáticas reemplazándolas por `${IMAGE_TAG:-...}` para backend y frontend.
2. **Configuración en Azure DevOps**:
   - Creación del proyecto `DevOps`.
   - Configuración de la Service Connection `acrdevopsvalenzano-sc` tipo Docker Registry hacia el ACR de Azure.
   - Creación del Environment `devops-vm-env`.
3. **Pipeline as Code**:
   - Creación de `azure-pipelines.yml` con triggers para `main`, `devel` y tags `v*`.

---

## ⚠️ Dificultades Encontradas y Soluciones Técnicas (Troubleshooting)

Durante el proceso se presentaron tres dificultades reales de integración que aportaron valiosas lecciones arquitectónicas:

### 1. Validación Estricta de Esquema: `Job DeployToVM: Environment is required`
* **Síntoma**: Al ejecutar por primera vez el pipeline, Azure DevOps falló inmediatamente antes de iniciar cualquier stage con el error: `Job DeployToVM: Environment is required`.
* **Causa Raíz**: En Azure Pipelines, la directiva `deployment:` no es un job regular; es una tarea especializada orientada a despliegues que **exige obligatoriamente** la propiedad `environment:` para vincular la auditoría. Como habíamos dejado comentada esa línea mientras definíamos el método de conexión, el validador de sintaxis rechazó el pipeline.
* **Solución**: Se especificó explícitamente `environment: $(vmEnvironmentName)` en el job `DeployToVM`.

### 2. Conflicto de Concurrencia en Git: `rejected (non-fast-forward)`
* **Síntoma**: Al intentar enviar el fix mediante `git push origin devel`, Git rechazó la operación indicando que la punta de la rama remota estaba adelantada.
* **Causa Raíz**: Al hacer clic en *"Save and run"* desde la interfaz web de Azure DevOps para dar de alta el pipeline, la plataforma generó automáticamente un commit en el repositorio remoto (`ebe1602 Set up CI with Azure Pipelines`). Como teníamos commits locales posteriores, se produjo una divergencia de ramas.
* **Solución**: Se resolvió de manera idiomática aplicando rebase:
  ```bash
  git pull --rebase origin devel
  git push origin devel
  ```
  Esto colocó nuestro commit de corrección (`bed6b6e fix(pipeline): ...`) limpiamente en la cima del historial sin generar commits de merge ruidosos.

### 3. Barrera de Seguridad de Ambientes: `Environment devops-vm-env could not be found`
* **Síntoma**: En la segunda ejecución, el pipeline falló indicando que el ambiente no existía o no estaba autorizado.
* **Causa Raíz**: Azure DevOps implementa gobernanza estricta por defecto: un pipeline no puede desplegar a un ambiente arbitrario o inexistente sin que un administrador del proyecto lo declare previamente.
* **Solución**: Se ingresó a la sección **Pipelines -> Environments** y se dio de alta el ambiente `devops-vm-env`, habilitando los permisos requeridos.

---

## 🧪 Pruebas y Resultados

- **Ejecución `#2.0.1` Exitosa**:
  - **Stage 1 (Semantic Versioning - 14s)**: Inspeccionó el commit `fix(pipeline): add required environment property to deployment job`. Reconoció el prefijo `fix:` e incrementó el PATCH sobre la base `2.0.0`, calculando automáticamente la versión `2.0.1` y renombrando la corrida.
  - **Stage 2 (CI: Build & Push a ACR - 1m 46s)**:
    - Verificó compilación de .NET 10 y React 18 en agentes limpios de Ubuntu.
    - Se autenticó contra ACR vía Service Connection.
    - Construyó y pusheó exitosamente las imágenes:
      - `acrdevopsvalenzano.azurecr.io/backend:2.0.1` y `backend:latest`.
      - `acrdevopsvalenzano.azurecr.io/frontend:2.0.1` y `frontend:latest`.
  - **Stage 3 (CD: Despliegue en VM - 15s)**: Ejecutó el ciclo contra el Environment `devops-vm-env`.

---

## 💡 Lecciones Aprendidas & Conclusiones

1. **Los orquestadores de CI/CD tienen contratos estrictos**: Un `deployment job` tiene un comportamiento y requisitos diferentes a un `job` tradicional; entender el metamodelo de la herramienta evita errores de esquema.
2. **Git es el estado central**: Cuando se configuran pipelines desde UIs web, estas suelen escribir commits en el repositorio. Trabajar con rebase mantiene el árbol de historial lineal y profesional.
3. **El valor del Versionado Semántico Automatizado**: En lugar de acordarse manualmente de cambiar un número en tres archivos distintos, la disciplina de **Conventional Commits** convierte a cada commit en la única fuente de verdad para el release de artefactos inmutables.

---

## 📌 Próximos Pasos
- Registrar la VM `vm-dev-ops` como recurso activo dentro del Environment `devops-vm-env` para ejecutar el script de despliegue (`docker compose pull && docker compose up -d`) directamente en el servidor.
