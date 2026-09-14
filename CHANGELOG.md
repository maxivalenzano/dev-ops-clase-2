# 📋 Changelog - Registro de Cambios

Todos los cambios notables de este proyecto se documentan en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y este proyecto adhiere a [Semantic Versioning (SemVer)](https://semver.org/lang/es/).

---

## [Unreleased] - Etapa 5

### Added
- **SonarQube Cloud SAST**: Instrumentación de compilación, análisis estático y Quality Gate automatizado en Azure Pipelines (`SonarCloudPrepare@3`, `SonarCloudAnalyze@3`, `SonarCloudPublish@3`).
- **Cobertura de Pruebas Dual**: Generación simultánea de reportes `opencover` y `cobertura` mediante Coverlet en .NET 10.
- **Auditoría Trivy Scanner**: Escaneo estático de vulnerabilidades y CVEs en dependencias y Containerfiles.
- **Changelog Dinámico en GitHub Releases**: Inyección automática del historial de commits y notas de versión en los Releases de GitHub vía pipeline.
- **Badges Dinámicos en README**: Badges en tiempo real de Azure Pipelines Build, SonarCloud Quality Gate, Security Rating, Vulnerabilities y Coverage.
- **Bitácora Técnica**: Documentación completa de la Etapa 5 en `docs/bitacora/2026-09-14-etapa-5-azure-pipelines-sast-sonarcloud.md`.

---

## [2.5.5] - 2026-09-14

### Added
- **Gobernanza Ágil en Azure DevOps**: Configuración de jerarquía de Work Items (Epics, Features, User Stories, Tasks, Bugs) en Process Template Agile.
- **Áreas y Sprints**: Taxonomía de Area Paths (`Frontend`, `Backend`, `Infraestructura`, `QA-Testing`) y Sprints 1, 2 y 3.
- **Dashboard & Wiki**: Dashboard ejecutivo de ingeniería y Azure DevOps Wiki oficial.

---

## [2.4.7] - 2026-09-14

### Added
- **Cluster Backend de 3 Nodos (Etapa 3)**: Despliegue de réplicas `backend-1`, `backend-2`, `backend-3` balanceadas por Nginx en modo Round-Robin con active failover (`proxy_next_upstream`).
- **Tablero Distribuido con Firma de Nodos (Etapa 1 & 2)**: Persistencia centralizada en Redis (`redis:7-alpine`) con firmas `createdByNode` y `servedByNode`.
- **Frontend React 18**: Componente `TaskBoard` con navegación por pestañas y aislamiento del laboratorio de caos (`ChaosLab`).
- **Pruebas Unitarias Backend (.NET 10)**: 42 pruebas automatizadas con xUnit, Moq y Mvc.Testing.

---

## [2.3.2] - 2026-09-13

### Added
- **Gobernanza y Quality Gates en CD**: Aprobaciones manuales en Azure DevOps Environments (`devops-vm-env`).
- **GitHub Deployments API**: Auditoría y estados automáticos en GitHub Deployments.
- **Sincronización de Releases & Packages**: Publicación automática de imágenes OCI a GitHub Packages (GHCR) y creación de GitHub Releases.

---

## [2.2.2] - 2026-09-13

### Fixed
- **Troubleshooting DNS en Gateway Nginx**: Mitigación de errores 502 al recrear contenedores mediante recarga de resolución DNS.
- **Inyección de Versión Visual**: Parámetro SemVer inyectado en Frontend React.

---

## [2.1.2] - 2026-09-12

### Added
- **Despliegue Continuo (CD) en Azure VM**: Automatización con agente pull en entorno Linux y Docker Compose.
- **Pipeline Multi-Stage**: Separación de etapas SemVer, CI y CD en Azure Pipelines.

---

## [2.0.0] - 2026-09-08

### Changed
- **Migración a .NET 10 LTS**: Actualización de Minimal API a .NET 10 y contenedorización inmutable con imágenes Alpine.
