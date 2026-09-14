# 📓 Bitácora del Proyecto

Registro cronológico de avances, experimentos, decisiones arquitectónicas y aprendizajes durante el desarrollo del laboratorio de DevOps.

---

## 📋 Entradas Recientes

- [**2026-09-14: Configuración de Dominio Personalizado (IONOS DNS), IP Estática en Azure y Nginx Gateway**](/bitacora/2026-09-14-configuracion-dominio-dns-ionos-nginx)
  - Vinculación del dominio `devops-maxivalenzano.com` a la infraestructura en Azure VM (`68.211.137.116`).
  - Configuración de zona DNS en IONOS con registros `A` (@) y `CNAME` (www).
  - Verificación de persistencia de IP pública estática en Azure.
  - Virtual host en Nginx y actualización transversal de URLs en GitHub, Azure DevOps Wiki y pipelines.

- [**2026-09-14: TP 1 - Etapa 5: CI con Análisis Estático de Seguridad (SAST), SonarQube Cloud y Badges**](/bitacora/2026-09-14-etapa-5-azure-pipelines-sast-sonarcloud)
  - Integración de SonarQube Cloud SAST para escaneo estático de vulnerabilidades, security hotspots y code smells en .NET 10.
  - Evaluación y publicación automatizada del Quality Gate oficial en Azure Pipelines con compuerta de paso de calidad.
  - Generación dual de reportes de cobertura (Coverlet OpenCover + Cobertura) para dashboards de SonarCloud y Azure DevOps.
  - Auditoría complementaria de dependencias y Containerfiles mediante Trivy Security Scanner.
  - Badges dinámicos oficiales de Azure Pipelines y SonarCloud incorporados en `README.md`.


- [**2026-09-14: Gobernanza Ágil en Azure DevOps, Estructuración de Work Items y Troubleshooting de Plataforma**](/bitacora/2026-09-14-configuracion-azure-devops-gobernanza-workitems)
  - Migración de Process Template de `Basic` a `Agile` en la organización `maxivalenzano/DevOps`.
  - Estructuración y carga de 107 Work Items jerárquicos (87 históricos cerrados y 20 pendientes en Sprints 1 y 2).
  - Configuración de Sprints 1, 2 y 3, taxonomía de Area Paths (`Frontend`, `Backend`, `Infraestructura`, `QA-Testing`).
  - Provisión de DevOps Wiki oficial y Dashboard de Ingeniería con métricas en tiempo real.
  - Diagnóstico y resolución de dificultades críticas: autenticación MCP (`TF400813`), error de mapeo en columnas Kanban, reglas de estados en `Task` y blindaje de CD.

- [**2026-09-14: Implementación Etapa 3 - Cluster de 3 Nodos Backend con Nginx y Alta Disponibilidad**](/bitacora/2026-09-14-etapa-3-nginx-cluster-3-nodos)
  - Escalado a 3 réplicas del microservicio backend (`backend-1`, `backend-2`, `backend-3`) con límites de recursos simétricos.
  - Configuración del upstream `backend_cluster` en Nginx con balanceo Round-Robin y detección de fallos.
  - Failover transparente sin caída (Zero-Downtime) con `proxy_next_upstream` y 3 reintentos (`proxy_next_upstream_tries 3`).
  - Persistencia compartida en Redis con visualización de firmas de nodo (`createdByNode` y `servedByNode`) en la UI.
- [**2026-09-13: TP 1 - Etapa 4: Pruebas Unitarias Backend (.NET 10 con xUnit, Moq y CI Gatekeeper)**](/bitacora/2026-09-13-pruebas-unitarias-dotnet-10-xunit)
  - Creación del proyecto `tests/Backend.Tests` en .NET 10 con xUnit, Moq y Microsoft.AspNetCore.Mvc.Testing.
  - Separación limpia en modelos (`TaskItem`) y capa de servicios (`ITaskService`, `TaskService`) con fallback resiliente.
  - Cobertura total de modelos, lógica con mocks de Redis (`IDatabase`), endpoints de salud y ciclo completo CRUD HTTP (24 tests en verde).
  - Integración en `azure-pipelines.yml` con `PublishTestResults@2` y `failTaskOnFailedTests: true` como Quality Gate bloqueante.
- [**2026-09-13: Implementación Etapa 2 - Tablero Distribuido (TaskBoard) con Firmas de Nodo sobre Redis**](/bitacora/2026-09-13-etapa-2-frontend-tablero-distribuido)
  - Desarrollo del componente React 18 `TaskBoard` en worktree aislado basado en el contrato `/api/tasks`.
  - Badges coloreados por nodo para firma de creación (`createdByNode`) y firma de lectura (`servedByNode`).
  - Navegación por pestañas para convivencia entre el Tablero y el Laboratorio de Caos y Métricas (`ChaosLab`).
  - Modularización del frontend y validación con `npm run build` en Vite.
- [**2026-09-13: TP 1 - Etapa 1: Persistencia en Redis y Tablero Distribuido con Firma de Nodos**](/bitacora/2026-09-13-tp1-etapa-1-redis-node-signature)
  - Almacenamiento centralizado de tareas en Redis (`redis:7-alpine`) con volumen persistente `redis-data`.
  - Arquitectura *Node Signature Board* con firma de creación (`createdByNode`) y servicio (`servedByNode`).
  - Integración de `StackExchange.Redis` en backend .NET 10 con conexión tolerante a fallos (`AbortOnConnectFail = false`).
  - Endpoints REST completos bajo `/api/tasks` manteniendo compatibilidad con endpoints de diagnóstico y caos.

- [**2026-09-13: Gobernanza en CD con Quality Gates, GitHub Deployments y Troubleshooting YAML**](/bitacora/2026-09-13-gobernanza-deployments-quality-gate)
  - Paso de Continuous Deployment a Continuous Delivery con compuertas de calidad manuales (Approvals).
  - Configuración de `devops-vm-env` y resolución de deadlocks con *"Allow approvers to approve their own runs"*.
  - Integración con GitHub Deployments API para auditoría y visualización del entorno `production`.
  - Diagnóstico y solución del error sintáctico de YAML (*Informational Run*) migrando a `jq -n`.
  - Curaduría minimalista del perfil del repositorio en GitHub.

- [**2026-09-13: Automatización de Releases, GHCR Packages y Portada en GitHub**](/bitacora/2026-09-13-automatizacion-releases-packages-github)
  - Sincronización desatendida entre Azure DevOps y GitHub con `GITHUB_PAT`.
  - Publicación dual OCI (ACR + GitHub Container Registry) para visibilidad en Packages.
  - Creación automática de GitHub Releases oficiales con changelog mediante la API REST.
  - Actualización automática de descripción del repo, enlace de la app en vivo y topics.

- [**2026-09-13: Troubleshooting de CD: DNS en Nginx (502) y Versión Visual**](/bitacora/2026-09-13-troubleshooting-dns-nginx-cd)
  - Diagnóstico de error 502 en Gateway Nginx y código de salida 22 en Smoke Test.
  - Causa raíz: Caché DNS estática en Nginx al recrear contenedores en Docker network.
  - Mitigación en pipeline con reinicio de gateway y re-resolución DNS.
  - Inyección de versión SemVer `2.1.2` y visualización de badge en el Frontend React.

- [**2026-09-12: Despliegue Continuo (CD) en VM Linux con Environments**](/bitacora/2026-09-12-despliegue-continuo-vm-azure)
  - Registro de VM Linux en Azure DevOps Environments como agente Pull-based.
  - Arquitectura segura sin exposición de puertos SSH ni claves en variables.
  - Automatización del pull de imágenes OCI desde ACR y recreación de contenedores con Compose.
  - Smoke testing y validación de salud de Nginx.

- [**2026-09-12: Diseño e Implementación de CI/CD en Azure DevOps y SemVer**](/bitacora/2026-09-12-diseno-ci-cd-azure-devops)
  - Diseño del pipeline multi-stage (`azure-pipelines.yml`) separando CI y CD.
  - Automatización de Versionado Semántico mediante Conventional Commits.
  - Publicación segura en Azure Container Registry (`acrdevopsvalenzano.azurecr.io`).
  - Despliegue continuo y validación con Smoke Tests en la VM Linux.

- [**2026-09-08: Migración a .NET 10 (LTS) y Contenedorización Inmutable**](/bitacora/2026-09-08-migracion-dotnet-10)
  - Actualización del microservicio backend a .NET 10 LTS preservando el diseño *single-file* (Minimal API).
  - Actualización de imágenes base en `Containerfile` (`10.0-alpine`).
  - Aplicación de principios DevOps: inmutabilidad del host VM y encapsulación hermética de dependencias.
  - Actualización de `compose.yaml` y versionado semántico SemVer `2.0.0`.

- [**2026-09-07: Infraestructura en Azure (VM Linux + ACR) y Estrategia Incremental**](/bitacora/2026-09-07-migracion-azure-vm-acr)
  - Despliegue de VM Linux (`Standard_B2als_v2`) y Azure Container Registry en `Chile Central`.
  - Configuración de Docker Engine y Docker Compose nativos en Ubuntu 24.04.
  - Empaquetado y sincronización del repositorio limpio vía SCP.
  - Planificación de crecimiento por etapas y ruteo centralizado en Nginx.

- [**2026-08-31: Inicialización del Lab & Documentación**](/bitacora/2026-08-31-inicio-lab)
  - Puesta en marcha de la estructura base del proyecto.
  - Implementación de VitePress como motor de documentación técnica y bitácora.
  - Configuración de Podman Compose y Native Pods.

---

## 💡 ¿Cómo agregar una nueva entrada a la bitácora?

1. Crea un nuevo archivo en el directorio `docs/bitacora/` con el formato `AAAA-MM-DD-titulo-breve.md`.
2. Agrega la entrada a la lista en `docs/bitacora/index.md` y en el sidebar de `docs/.vitepress/config.mts`.
3. Seguí la siguiente estructura sugerida:

```markdown
# 🚀 [Título de la sesión o hito]

**Fecha**: AAAA-MM-DD  
**Autor**: Tu Nombre / Equipo  

---

## 🎯 Objetivos de la sesión
- Objetivo 1
- Objetivo 2

---

## 🛠️ Acciones Realizadas
- Detalle de lo implementado o probado...

---

## 🧪 Pruebas y Resultados
- Qué comandos ejecutaste y qué salidas obtuviste...

---

## 💡 Lecciones Aprendidas & Decisiones
- Qué funcionó, qué falló y por qué...

---

## 📌 Próximos Pasos
- Tareas pendientes para la próxima sesión.
```
