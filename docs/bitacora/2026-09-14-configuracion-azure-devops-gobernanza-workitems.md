# 🚀 2026-09-14: Gobernanza Ágil en Azure DevOps, Estructuración de Work Items y Troubleshooting de Plataforma

**Fecha**: 2026-09-14  
**Hito**: Transformación integral de la gestión del proyecto en Azure DevOps (`maxivalenzano/DevOps`): migración de proceso a *Agile*, jerarquización completa del historial y backlog pendiente (107 Work Items entre Épicas, Features, Historias y Tareas), configuración de Sprints, Áreas, Dashboard de Ingeniería, Wiki y resolución de problemas críticos de API y reglas de negocio.

---

## 🎯 Objetivos de la sesión

1. **Modernización de la Gobernanza y Trazabilidad**: Dejar atrás el seguimiento informal o documentos locales aislados (`PLAN_TP1.md`) para centralizar todo el ciclo de vida del laboratorio en Azure DevOps Boards bajo el framework Ágil.
2. **Reconstrucción Histórica del Trabajo Realizado**: Modelar como Work Items cerrados (`Closed`) todas las actividades ejecutadas desde el inicio del laboratorio (infraestructura, .NET 10, pipelines CI/CD, despliegues a la VM, gobernanza de CD, Redis, Node Signature y Frontend Tablero Distribuido).
3. **Planificación y Carga de Tareas Pendientes**: Incorporar las etapas 5 (Testing automatizado y SAST), 6 (Despliegue con Redis en VM Azure), 6B (Dominio personalizado y DNS) y 7 (Informe final y defensa) en estado `New`, asignadas a sus respectivos Sprints.
4. **Configuración Integral del Entorno Azure DevOps**:
   - Migración de Process Template de `Basic` a `Agile`.
   - Parametrización de Sprints (Sprint 1 actual, Sprint 2 y Sprint 3 futuros).
   - Estructuración de Áreas funcionales (`Frontend`, `Backend`, `Infraestructura`, `QA-Testing`).
   - Habilitación de la Wiki oficial del proyecto y armado del Dashboard de Ingeniería.
5. **Diagnóstico y Resolución de Dificultades de Plataforma**: Registrar las causas raíz y soluciones de los bloqueos encontrados con la API de Azure DevOps, el protocolo MCP, reglas de transición de estados y mapeos del tablero Kanban.

---

## 🏛️ 1. Arquitectura de Gobernanza Ágil en Azure DevOps

### 1.1 Modelo Jerárquico de Trabajo
Para reflejar con fidelidad un flujo de ingeniería DevOps profesional, se estructuró la jerarquía estándar de cuatro niveles:

```
┌─────────────────────────────────────────────────────────────┐
│                       ÉPICA (Epic)                          │
│          Gran iniciativa de negocio o entrega mayor         │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    CARACTERÍSTICA (Feature)                 │
│        Hito técnico o funcional entregable (1 a 2 semanas)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 HISTORIA DE USUARIO (User Story)            │
│       Incremento de valor verificable con Acceptance Criteria│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                        TAREA (Task)                         │
│            Actividad técnica atómica de implementación      │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Estructura de Sprints y Calendario
Se configuraron las iteraciones del equipo (`DevOps Team`) alineadas al cronograma de entregas:

| Sprint | Inicio | Fin | Estado | Enfoque Principal |
| :--- | :--- | :--- | :--- | :--- |
| **Sprint 1** | 2026-09-07 | 2026-09-20 | **Actual (Active)** | Infraestructura base, CI/CD, Redis, Frontend Tablero y Suite de Testing / SAST (Etapa 5). |
| **Sprint 2** | 2026-09-21 | 2026-10-04 | Futuro | Despliegue con Redis en Azure VM (Etapa 6), Dominio / SSL (Etapa 6B) e Informe Final (Etapa 7). |
| **Sprint 3** | 2026-10-05 | 2026-10-18 | Futuro | Monitoreo avanzado, métricas Prometheus/Grafana y buffer para evolutivos. |

### 1.3 Taxonomía por Rutas de Área (*Area Paths*)
Se establecieron rutas de área para categorizar el backlog y habilitar filtrado granular en tableros y dashboards:
- `DevOps\Infraestructura`: VM Linux, Azure Container Registry, redes Docker, Nginx Gateway, Podman.
- `DevOps\Backend`: API Minimal en .NET 10 LTS, Redis `StackExchange.Redis`, Chaos Engineering.
- `DevOps\Frontend`: Aplicación SPA React 18, Vite, componentes de tablero y telemetría.
- `DevOps\QA-Testing`: Pruebas unitarias, análisis estático de seguridad (SAST), integración y smoke tests.

---

## ⚠️ 2. Dificultades Técnicas Encontradas y Soluciones

Durante la configuración programática y automatizada de Azure DevOps surgieron diversos desafíos técnicos que requirieron diagnóstico profundo a nivel de API REST y modelo de datos:

### 🚨 Dificultad 1: Error de Autenticación en Servidor MCP de Azure DevOps (`TF400813`)
- **Síntoma**: Al invocar herramientas del servidor MCP oficial `@azure-devops/mcp` configurado en el entorno, las llamadas fallaban con error `TF400813: The user '' is not authorized to access this resource` o iniciaban flujos de autenticación interactiva en navegador que no pueden completarse en un entorno de agente desatendido.
- **Causa Raíz**: El servidor MCP local estaba configurado esperando credenciales interactivas de Azure CLI / MSAL en lugar de inyectar directamente el Personal Access Token (PAT).
- **Solución Implementada**: Se desarrolló un script de automatización en Node.js que interactúa directamente contra la API REST de Azure DevOps (`https://dev.azure.com/maxivalenzano/DevOps/_apis/`) utilizando cabeceras HTTP de autenticación básica estándar:
  ```javascript
  const authHeader = `Basic ${Buffer.from(`:${PAT}`).toString('base64')}`;
  ```
  Esto garantizó una ejecución 100% determinista, rápida y sin intervención manual para la administración de la organización.

---

### 🚨 Dificultad 2: Incompatibilidad de Esquema de Proceso (*Basic* vs *Agile*)
- **Síntoma**: Al intentar registrar Work Items del tipo `Feature` o `User Story`, la API devolvía un código `400 Bad Request` indicando que dichos tipos de elemento no existían en el proyecto.
- **Causa Raíz**: El proyecto fue creado originalmente con la plantilla de proceso **Basic** de Azure DevOps, la cual únicamente reconoce `Epic`, `Issue` y `Task`. En `Basic`, no existe el concepto nativo de `Feature` ni de `User Story`.
- **Solución Implementada**:
  1. Se consultó el listado de plantillas de proceso de la organización mediante `GET /_apis/process/processes`.
  2. Se localizó el identificador único del proceso Agile oficial (`adcc42ab-9882-485e-a3ed-7678f01f66bc`).
  3. Se ejecutó una migración de proceso sobre el proyecto mediante un parche en la API:
     ```http
     PATCH /_apis/projects/79469e96-6e2a-4318-971c-72049e0e37bc?api-version=7.1-preview.4
     Content-Type: application/json

     {
       "processTemplate": {
         "templateTypeId": "adcc42ab-9882-485e-a3ed-7678f01f66bc"
       }
     }
     ```
  4. Una vez migrado a *Agile*, quedaron inmediatamente habilitados los tipos `Feature`, `User Story`, `Bug` y `Task`.

---

### 🚨 Dificultad 3: Desincronización y Crash del Tablero Kanban (*State Mappings Error*)
- **Síntoma**: Al acceder en la interfaz gráfica a **Boards > Boards**, aparecía un banner rojo bloqueante:
  > *"One or more columns don't have a valid state mapping. Please correct the state mappings to view the board."*
  El tablero era incapaz de renderizar las columnas y quedaba completamente inutilizable.
- **Causa Raíz**: Al migrar la plantilla de proceso de *Basic* a *Agile*, las columnas existentes del tablero (`To Do`, `Doing`, `Done`) mantenían las definiciones de estado del tipo anterior (`Issue`: `To Do`, `Doing`, `Done`), pero el tablero de nivel requerimientos en Agile espera elementos del tipo `User Story`, cuyos estados nativos válidos son `New`, `Active`, `Resolved`, `Closed` o `Removed`. Al no coincidir los nombres de los estados, el motor de rendering de Azure DevOps abortaba por incoherencia de mapeo.
- **Solución Implementada**:
  Se consultó la definición de columnas del tablero mediante `GET /_apis/work/boards/Stories` y se actualizó vía `PUT /_apis/work/boards/Stories/columns` con el mapeo explícito de estados para `User Story`:
  - Columna **To Do** $\rightarrow$ Estado `New`
  - Columna **Doing** $\rightarrow$ Estado `Active`
  - Columna **Done** $\rightarrow$ Estado `Closed`

  Tras la actualización vía REST, el tablero Kanban se reestableció inmediatamente con visualización perfecta de todas las tarjetas.

---

### 🚨 Dificultad 4: Reglas de Transición de Estados en Work Items de Tipo *Task*
- **Síntoma**: Al intentar crear las tareas históricas directamente en estado `Closed` mediante `POST /_apis/wit/workitems/$Task`, la API rechazaba la petición con error:
  > `VS403207: The field 'State' has an invalid value 'Closed' for a new work item of type 'Task'.`
- **Causa Raíz**: Las reglas de validación del motor de Work Items de Azure DevOps en la plantilla Agile estipulan que un elemento de tipo `Task` debe nacer obligatoriamente en estado inicial `New`. No está permitido instanciarlo de forma directa en un estado terminal sin pasar por el ciclo de vida del flujo.
- **Solución Implementada**:
  Se implementó un patrón de creación en dos etapas (*Two-Step Creation Pattern*) en el script de carga:
  1. **Creación inicial**: Se crea la tarea con estado `New`, asignándole título, descripción, área, iteración y enlace padre jerárquico (`System.LinkTypes.Hierarchy-Reverse`).
  2. **Transición inmediata**: Se aplica inmediatamente un `PATCH /_apis/wit/workitems/{id}` con la operación:
     ```json
     [
       { "op": "add", "path": "/fields/System.State", "value": "Closed" },
       { "op": "add", "path": "/fields/Microsoft.VSTS.Common.ClosedReason", "value": "Completed" }
     ]
     ```
  Esto permitió cargar las 56 tareas históricas ya cerradas respetando rigurosamente las restricciones del motor de flujo de Azure DevOps.

---

### 🚨 Dificultad 5: Visibilidad de la Categoría *Epics* en la Navegación del Equipo
- **Síntoma**: Tras la migración a Agile, el menú desplegable de navegación de Boards solo mostraba *Backlog items / Stories*, sin permitir seleccionar la vista de *Epics* o *Features*.
- **Causa Raíz**: Por defecto, en equipos recién migrados o creados en Azure DevOps, las categorías superiores del backlog (`Microsoft.EpicCategory`) vienen desactivadas a nivel de configuración de equipo para simplificar la vista inicial.
- **Solución Implementada**:
  Se actualizó la configuración del equipo (`DevOps Team`) mediante `PATCH /_apis/work/teamsettings`:
  ```json
  {
    "backlogVisibilities": {
      "Microsoft.EpicCategory": true,
      "Microsoft.FeatureCategory": true,
      "Microsoft.RequirementCategory": true
    }
  }
  ```
  Con este cambio, la vista de Épicas quedó inmediatamente visible en la barra superior de Boards.

---

### 🚨 Dificultad 6: Restricción de Ejecución Segura en Etapa de CD de Azure Pipelines
- **Síntoma**: El pipeline multi-stage ejecutaba la etapa de Continuous Deployment (CD) potencialmente en ramas no deseadas o Pull Requests si no se filtraba cuidadosamente la condición de ejecución a nivel de etapa.
- **Solución Implementada**:
  Se agregó una condición explícita y robusta a la etapa `CD` en `azure-pipelines.yml`:
  ```yaml
  condition: and(succeeded(), in(variables['Build.SourceBranch'], 'refs/heads/main', 'refs/heads/devel', 'refs/tags/v*'), ne(variables['Build.Reason'], 'PullRequest'))
  ```
  Asimismo, se aisló la publicación a GitHub Packages (GHCR) para que opere de forma no bloqueante (`try/catch` en shell), asegurando que una indisponibilidad temporal o expiración de token en GitHub no interrumpa el flujo crítico de despliegue a la VM de Azure.

---

## 📊 3. Resumen de Work Items Cargados (Total: 107)

Se completó la sincronización total del proyecto, alcanzando una cobertura de 107 elementos de trabajo distribuidos de la siguiente manera:

```
Total Work Items: 107
 ├── 87 Históricos (Estado: Closed)
 │    ├── 4 Épicas
 │    ├── 10 Features
 │    ├── 17 User Stories
 │    └── 56 Tasks
 └── 20 Pendientes (Estado: New / Sprints 1 y 2)
      ├── 4 Features
      ├── 4 User Stories
      └── 12 Tasks
```

### 3.1 Desglose de Épicas y Features Históricas (Cerradas)

1. **Épica #10: Infraestructura Base y Contenedorización**
   - *Feature #7*: Inicialización del Laboratorio, Docs y Podman (`Sprint 1`)
   - *Feature #19*: Infraestructura Cloud en Azure (VM Linux + ACR) (`Sprint 1`)
   - *Feature #25*: Modernización de Arquitectura a .NET 10 LTS (`Sprint 1`)
2. **Épica #31: Pipeline de CI/CD Multi-Stage y Gobernanza**
   - *Feature #32*: Pipeline Multi-Stage CI/CD y SemVer Automático (`Sprint 1`)
   - *Feature #42*: Despliegue Continuo (CD) en VM con Environments (`Sprint 1`)
   - *Feature #49*: Troubleshooting Nginx Gateway, DNS y Badges (`Sprint 1`)
3. **Épica #58: TP 1 - Sistema Distribuido y Persistencia Centralizada**
   - *Feature #59*: Automatización de Releases, GHCR Packages y GitHub Sync (`Sprint 1`)
   - *Feature #68*: Gobernanza en CD: Quality Gates y Deployments API (`Sprint 1`)
   - *Feature #79*: TP 1 - Etapa 1: Persistencia en Redis y Firma de Nodos (`Sprint 1`)
   - *Feature #88*: TP 1 - Etapa 2: Frontend Tablero Distribuido con Badges (`Sprint 1`)
4. **Épica #78: Testing, Calidad y Buenas Prácticas** (Transversal a todas las etapas).

### 3.2 Desglose de Features y Tareas Pendientes (Etapas 5, 6, 6B y 7)

A partir del análisis de `PLAN_TP1.md`, se incorporaron las siguientes actividades para completar los objetivos de la materia:

| ID | Tipo | Título | Sprint | Área | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **#97** | **Feature** | **Etapa 5: Testing Automatizado, SAST y Badges de Calidad** | Sprint 1 | QA-Testing | `New` |
| #98 | User Story | Suite de Pruebas Unitarias y Análisis Estático en CI | Sprint 1 | QA-Testing | `New` |
| #99 | Task | Tests unitarios para TaskService y RedisRepository en backend | Sprint 1 | QA-Testing | `New` |
| #100 | Task | Paso de SAST en azure-pipelines.yml con Roslyn Security Guard o Trivy | Sprint 1 | QA-Testing | `New` |
| #101 | Task | Incorporación de badges de cobertura y estado de build en README | Sprint 1 | QA-Testing | `New` |
| **#102** | **Feature** | **Etapa 6: Despliegue de Redis y Tablero en Azure VM (Producción)** | Sprint 2 | Infraestructura | `New` |
| #103 | User Story | Actualización de Topología de Producción con Contenedor Redis | Sprint 2 | Infraestructura | `New` |
| #104 | Task | Actualizar compose.yaml de producción con servicio redis y volumen persistente | Sprint 2 | Infraestructura | `New` |
| #105 | Task | Validar conexión y firewall local entre Backend y Redis en Azure VM | Sprint 2 | Infraestructura | `New` |
| #106 | Task | Smoke test de persistencia e inspección de claves redis-cli en servidor | Sprint 2 | Infraestructura | `New` |
| **#107** | **Feature** | **Etapa 6B: Configuración de Dominio Personalizado y DNS** | Sprint 2 | Infraestructura | `New` |
| #108 | User Story | Enrutamiento de Dominio DNS y Certificado SSL/TLS | Sprint 2 | Infraestructura | `New` |
| #109 | Task | Configuración de registro DNS tipo A hacia IP pública de Azure VM | Sprint 2 | Infraestructura | `New` |
| #110 | Task | Configuración de Certbot Let's Encrypt o certificado SSL en Nginx Gateway | Sprint 2 | Infraestructura | `New` |
| #111 | Task | Redirección forzada HTTP a HTTPS y validación de cabeceras seguras | Sprint 2 | Infraestructura | `New` |
| **#112** | **Feature** | **Etapa 7: Documentación de Cierre, Métricas y Presentación TP1** | Sprint 2 | General | `New` |
| #113 | User Story | Elaboración de Informe Técnico Final y Demostración en Vivo | Sprint 2 | General | `New` |
| #114 | Task | Consolidar bitácoras y lecciones aprendidas en la documentación VitePress | Sprint 2 | General | `New` |
| #115 | Task | Elaborar diagrama de arquitectura final C4 y matriz de decisiones técnicas | Sprint 2 | General | `New` |
| #116 | Task | Grabar y documentar demo funcional de caos, escalado y persistencia en Redis | Sprint 2 | General | `New` |

---

## 📈 4. Dashboard de Ingeniería y Wiki Oficial

Para maximizar la visibilidad y aprovechamiento de Azure DevOps, se provisionaron dos activos clave:

1. **DevOps Wiki (`DevOps.wiki`)**:
   - Página `/Overview`: Documento de arquitectura, referencias a los repositorios, manual de credenciales de infraestructura, convenciones de ramas (`main`, `devel`, worktrees) y lineamientos de versionado SemVer.
2. **Dashboard de Ingeniería (`DevOps Engineering Dashboard`)**:
   - Visualización de estado del pipeline `dev-ops-ci-cd`.
   - Conteo y estado de Work Items activos vs cerrados.
   - Burndown de tareas para el `Sprint 1`.
   - Accesos directos a la documentación y repositorios.

---

## 💡 Lecciones Aprendidas y Recomendaciones

1. **La consistencia de procesos condiciona las herramientas**: Al cambiar el proceso de una organización en Azure DevOps (p.ej. de Basic a Agile), es imperativo auditar las definiciones de columnas de los tableros Kanban, ya que los mapeos de estado no se migran automáticamente y generan errores bloqueantes en la UI.
2. **Las restricciones de flujo son contratos de datos**: El motor de Work Items impone reglas de transición que protegen la integridad de los datos. En automatizaciones de carga masiva, es preferible utilizar patrones transaccionales controlados (crear en `New` $\rightarrow$ parchear a `Closed`) en lugar de forzar estados inválidos.
3. **Desacoplar servicios críticos de secundarios en CI/CD**: El pipeline debe priorizar el despliegue hacia la infraestructura primaria (Azure ACR y VM). Publicaciones auxiliares como GitHub Packages deben ejecutarse con tolerancia a fallos para no interrumpir el flujo de entrega de valor ante incidencias en proveedores secundarios.
4. **Trazabilidad total entre código y gestión**: Al vincular cada commit y pipeline a Work Items concretos en Azure DevOps, se logra visibilidad de extremo a extremo, facilitando auditorías y justificaciones técnicas durante la defensa del trabajo práctico.
