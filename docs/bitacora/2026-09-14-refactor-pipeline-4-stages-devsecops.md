# ⚙️ Refactorización de Pipeline CI/CD: Arquitectura Desacoplada en 4 Stages

**Fecha:** 2026-09-14  
**Rama:** `feature/pipeline-4-stages`  
**Autor:** Maxi Valenzano  
**Componentes:** Azure Pipelines (`azure-pipelines.yml`), SonarQube Cloud, Docker Compose, ACR/GHCR, `README.md`.

---

## 🎯 Justificación Arquitectónica

Inicialmente, el pipeline integraba en un único **Stage 2 (CI)** tanto la validación de código, tests unitarios, análisis SAST como la construcción y subida de imágenes OCI. Esta aproximación monolítica presentaba desventajas operativas:
1. **Falta de *Fail-Fast* real**: El fallo de un paso intermedio (ej. SonarQube Cloud o tests) ocurría dentro del mismo contenedor conceptual de empaquetado, impidiendo reintentar de forma independiente.
2. **Logs y Observabilidad Monolíticos**: Dificultaba identificar rápidamente si un fallo correspondía a calidad de código, fallas de tests, errores de npm o timeouts de red contra el Azure Container Registry (ACR).
3. **Desperdicio de Recursos de Cómputo**: No había una barrera formal entre la certificación de calidad y el empaquetado de artefactos inmutables.

---

## 🏗️ Nueva Arquitectura en 4 Stages

```text
[ 1. Versioning ] 
       │ (SemVer automático con Conventional Commits)
       ▼
[ 2. Quality Gate & SAST ]
       ├─ Job A: Backend .NET 10 (42 Tests xUnit + Cobertura + SonarQube Cloud dotnet mode)
       └─ Job B: Frontend React 18 / Vite Build + Auditoría Trivy SAST
       │
       ▼ (Solo si Quality Gate pasa al 100%)
[ 3. Packaging OCI ]
       ├─ Build & Push Backend Container (ACR + GHCR)
       └─ Build & Push Frontend Container (ACR + GHCR)
       │
       ▼ (Solo en ramas principales y con empaquetado exitoso)
[ 4. Continuous Delivery (CD) ]
       ├─ Despliegue en Azure VM (devops-vm-env) con Docker Compose
       ├─ Smoke Tests y verificación Zero-Downtime
       └─ Inyección dinámica de Changelog y creación de GitHub Release
```

---

## 📋 Detalle de Cambios en `azure-pipelines.yml`

* **`stage: QualityGate`**:
  - `BackendQuality`: Instrumentación con `SonarCloudPrepare@3` (`scannerMode: dotnet`), compilación, ejecución de tests xUnit con recolección dual (OpenCover y Cobertura) y publicación de resultados.
  - `FrontendAndSecurity`: Verificación de build de Vite (`npm run build`) y escaneo estático de seguridad con **Trivy Scanner** (`trivy fs`).
* **`stage: Packaging`**:
  - Depende estrictamente de `Versioning` y `QualityGate`.
  - Autenticación en ACR y construcción de imágenes Docker multi-stage inmutables con tags SemVer y `latest`.
* **`stage: CD`**:
  - Depende de `Versioning` y `Packaging`.
  - Despliegue pull-based en VM Ubuntu Azure, Smoke Test HTTP contra el dominio `devops-maxivalenzano.com` y publicación del Release de GitHub con changelog formateado.

---

## 🚀 Beneficios Obtenidos
1. **Reintentos Granulares**: Si falla la red de ACR o GHCR, se puede reintentar únicamente el Stage de *Packaging* sin re-ejecutar los tests ni el análisis de SonarCloud.
2. **Visibilidad en Azure DevOps UI**: Tablero visual claro con estados independientes para cada etapa del ciclo de vida.
3. **Alineación con Estándares DevSecOps**: Separación estricta de responsabilidades (*Separation of Concerns*).
