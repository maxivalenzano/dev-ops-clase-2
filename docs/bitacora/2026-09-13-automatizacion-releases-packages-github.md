# 📓 Bitácora: Automatización de Releases, GHCR Packages y Portada en GitHub

**Fecha:** 13 de Septiembre de 2026  
**Autor:** Maxi Valenzano  
**Materia / Proyecto:** DevOps Lab - Clase 2  
**Entorno:** Azure DevOps + GitHub (`maxivalenzano/dev-ops-clase-2`) + VM Azure (`devops-maxivalenzano.com` / `68.211.137.116`)

---

## 🎯 Objetivo

Lograr una sincronización 100% desatendida entre el pipeline de **Azure DevOps** y la presentación visual del repositorio en **GitHub**. Cada push en la rama `devel` (y `main`) debe:
1. Publicar contenedores OCI vinculados en **GitHub Packages (GHCR)** (`backend` y `frontend`).
2. Generar el **Tag SemVer** y sellar el **GitHub Release oficial** con changelog automático.
3. Actualizar la sección **About**, el enlace en vivo del proyecto (`http://devops-maxivalenzano.com`) y los **Topics** técnicos.
4. Desplegar de forma continua en la máquina virtual Linux en Azure.

---

## 🔍 Diagnóstico Inicial

En la portada del repositorio en GitHub:
- **About**: No contenía descripción, temas (topics) ni enlace a la aplicación en vivo.
- **Releases**: Se limitaba a un tag de Git (`v2.1.2`), sin release formal ni notas de publicación.
- **Packages**: Mostraba *"No packages published"*, ya que las imágenes se enviaban únicamente a Azure Container Registry (ACR).

---

## 🛠️ Implementación

### 1. Publicación Dual OCI en CI (ACR + GitHub Packages / GHCR)
En la etapa `CI` de `azure-pipelines.yml`, se incorporó la etiqueta estándar OCI:
```dockerfile
--label "org.opencontainers.image.source=https://github.com/maxivalenzano/dev-ops-clase-2"
```
y la autenticación segura contra `ghcr.io` utilizando el token secreto `GITHUB_PAT`. Esto vincula automáticamente las imágenes al repositorio bajo la pestaña **Packages**.

### 2. Creación Automática de GitHub Releases
En la etapa `CD`, luego de validar los *Smoke Tests* locales en la VM, el pipeline invoca la API REST de GitHub (`POST /repos/.../releases`) con:
- Tag calculado (`v$(SEMVER_TAG)`).
- `generate_release_notes: true` para autogenerar el changelog de commits.

### 3. Sincronización de Metadata del Repositorio
Se parametrizaron llamadas a la API de GitHub para actualizar:
- **Description**: Resumen de microservicios y arquitectura.
- **Homepage**: `http://devops-maxivalenzano.com` (enlace directo a la app desplegada).
- **Topics**: `devops`, `azure-devops`, `docker-compose`, `podman`, `dotnet10`, `react18`, `nginx`, `semver`, `ci-cd`, `microservices`.

### 4. Enriquecimiento del README
Se incorporaron *shields* dinámicos en la cabecera de `README.md` indicando el estado del demo, el último release, los paquetes GHCR y el stack tecnológico.

---

## 🚀 Prerequisito en Azure DevOps

Para activar el flujo completo, basta con definir la variable en la UI del pipeline en Azure DevOps:
- **Nombre:** `GITHUB_PAT`
- **Valor:** Personal Access Token (Classic con scopes `repo`, `write:packages`, o Fine-grained con permisos sobre Contents, Packages y Administration).
- **Seguridad:** Marcar como valor secreto (ícono de candado).
