# 🛡️ 2026-09-14: Troubleshooting de Quality Gate: SonarQube Cloud API 403, Gobernanza de Branches y Migración a Tareas v4

**Fecha:** 2026-09-14  
**Autor:** Maxi Valenzano  
**Hito:** Diagnóstico forense y resolución integral del error 403 Forbidden en la publicación del Quality Gate de SonarQube Cloud en Azure Pipelines, resolución de restricciones del plan Free para ramas secundarias, configuración de `devel` como Main Branch oficial, corrección de advertencias de SCM/cobertura y migración a las tareas v4.

---

## 🎯 Objetivos de la sesión

1. Resolver la falla bloqueante en la tarea `Publish Quality Gate Result` (`SonarCloudPublish@3`) de Azure Pipelines (`API GET '/api/qualitygates/project_status' failed. Error message: Request failed with status code 403`).
2. Diagnosticar las causas de autenticación, tipos de token y permisos en la Service Connection entre Azure DevOps y SonarQube Cloud.
3. Comprender las políticas y limitaciones del plan Free de SonarQube Cloud respecto a la visibilidad (Private vs Public) y la restricción de análisis exclusivo a la rama principal (*Main Branch*).
4. Configurar la rama de integración continua `devel` como la **MAIN BRANCH** oficial en SonarQube Cloud.
5. Blindar el archivo `azure-pipelines.yml` mediante condiciones de ejecución para que el análisis SAST solo se ejecute en `devel` y no interrumpa pipelines disparados por tags de versión (`v*`) o ramas secundarias.
6. Resolver las advertencias de *Shallow clone*, rutas de reportes de cobertura OpenCover y migrar de las tareas deprecadas `@3` a la versión oficial `@4`.

---

## ⚠️ Dificultades Encontradas y Diagnóstico Forense

### 1. El Incidente: Falla en `SonarCloudPublish` con HTTP 403 Forbidden
* **Síntoma:**  
  En la ejecución del Stage 2 (`Quality Gate & SAST`), los pasos de compilación .NET 10, ejecución de 42 tests xUnit y el escaneo estático `SonarCloudAnalyze@3` finalizaron exitosamente (`Analysis succeeded`).  
  Sin embargo, inmediatamente después, la tarea `Evaluar y Publicar Quality Gate SonarQube Cloud` (`SonarCloudPublish@3`) falló con:
  ```text
  ##[error][ERROR] SonarQube Cloud: Error retrieving analysis: API GET '/api/qualitygates/project_status' failed. Error message: Request failed with status code 403.
  ##[error][ERROR] SonarQube Cloud: Error while executing task Publish: Could not fetch analysis for ID '6bcc5dbc-8c75-4cfe-9866-c6137de40662'
  ##[error]Could not fetch analysis for ID '6bcc5dbc-8c75-4cfe-9866-c6137de40662'
  ```
* **Causa Raíz de Autenticación (Token Scope):**  
  Al inspeccionar la Service Connection en Azure DevOps, se detectó que el token configurado era `Analyze "DevOps"`. Este es un **Project Analysis Token** autogenerado por el asistente de SonarCloud.  
  Dichos tokens poseen permisos de subida (`Execute Analysis`), pero **carecen de permisos de lectura (`Browse`)** para consultar el estado del Quality Gate a través de la API REST (`/api/qualitygates/project_status`).

### 2. Restricciones del Plan Free y Visibilidad del Proyecto (Private vs Public)
* **Investigación de Visibilidad:**  
  A pesar de que el repositorio en GitHub ([maxivalenzano/dev-ops-clase-2](https://github.com/maxivalenzano/dev-ops-clase-2)) es **Público**, el proyecto en SonarCloud `maxivalenzano_DevOps` se encontraba configurado inicialmente como **Private**.  
* En el plan gratuito de SonarQube Cloud, los proyectos privados solo ofrecen un periodo de prueba de 14 días y no permiten análisis de branches/PRs sin contratar el plan de pago (*Team Plan* desde $34/mes).  
* **Solución aplicada:** Se ajustó la visibilidad en **Administration > Permissions > Project visibility** a **Public**. Esto habilita análisis ilimitado y gratuito para proyectos de código abierto.

### 3. Conflicto de Branch Principal (`main` vs `devel`) en SonarQube Cloud
* **El Problema:**  
  Incluso con visibilidad pública, al ingresar a **Project > Branches**, SonarCloud mostraba la advertencia:
  > *"Branch Analysis: Your current plan covers the analysis of the main branch only. SonarQube Cloud can analyze all branches in your project [Upgrade plan]"*
  
  Y en la tabla de ramas:
  * `main` figuraba como `MAIN BRANCH`.
  * `devel` figuraba bajo *Short-lived branches* como `Not analyzed` con el botón de `Upgrade`.
* **Causa Raíz:**  
  En el laboratorio DevOps, la rama principal de desarrollo e integración continua es **`devel`** (así como la rama predeterminada en GitHub). SonarCloud asumió `main` por defecto, por lo que cualquier ejecución del pipeline sobre `devel` era tratada como una rama secundaria no cubierta por el plan gratuito, arrojando el error 403 al consultar el Quality Gate.

---

## 🛠️ Solución Implementada y Arquitectura de Blindaje

### 1. Configuración de `devel` como Main Branch en SonarQube Cloud
Para alinear la plataforma con el flujo Git del proyecto:
1. En la tabla *Short-lived branches*, se eliminó la entrada huérfana de `devel` (opción *Delete branch*).
2. En la tabla *Long-lived branches*, se renombró la rama principal `main` a **`devel`** (*Rename branch*).
3. Con esto, `devel` pasó a ser formalmente la **MAIN BRANCH** en SonarQube Cloud, habilitando el análisis gratuito e ilimitado del Quality Gate.

### 2. Blindaje Condicional en `azure-pipelines.yml`
Dado que el plan gratuito solo analiza `devel`, si el pipeline se ejecuta por un tag de release (ej: `refs/tags/v2.8.3`) o en otra rama, SonarCloud rechazaría la consulta.  
Se incorporó una directiva condicional estricta en las tareas de SonarQube Cloud:
```yaml
condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/devel'))
```
* **Comportamiento en `devel`:** Ejecución completa del escaneo SAST, validación estricta del Quality Gate y generación de métricas de seguridad.
* **Comportamiento en tags (`v*`) u otras ramas:** Las tareas de SonarCloud se omiten limpiamente. La compilación .NET 10, la ejecución de pruebas xUnit, la publicación de reportes en Azure DevOps, la construcción de contenedores OCI hacia ACR/GHCR y el despliegue CD hacia la VM continúan sin interrupciones.

### 3. Migración a Tareas Oficiales v4 (Resolución de Deprecaciones)
Las tareas `@3` generaban 6 advertencias amarillas de obsolescencia en Azure DevOps. Se actualizaron a la versión 4:
* `SonarCloudPrepare@4`
* `SonarCloudAnalyze@4`
* `SonarCloudPublish@4`

### 4. Corrección de SCM Blame y Rutas de Cobertura
* **Historial Completo (`fetchDepth: 0`):** Se añadió al paso `checkout: self` en el job `BackendQuality`, resolviendo las advertencias `Shallow clone detected` y `Could not find ref 'main'`.
* **Directorio de Cobertura Centralizado:** Se agregó `--results-directory $(Agent.TempDirectory)` en `dotnet test`. Esto garantiza que los archivos `test_results.trx`, `coverage.opencover.xml` y `coverage.cobertura.xml` se ubiquen exactamente en la carpeta temporal compartida del agente.

---

## 🧪 Validación y Resultados

1. **Pipeline Run #2.8.3 en Azure DevOps:**
   - **Stage 1 (Semantic Versioning):** Cálculo exitoso de versión SemVer (`2.8.3`).
   - **Stage 2 (Quality Gate & SAST):**
     - Job `Backend .NET 10`: Compilación exitosa, 42 tests unitarios aprobados (100% pass), cobertura publicada y Quality Gate evaluado como **PASSED** sin errores.
     - Job `Frontend & Trivy`: Build Vite completado y auditoría de vulnerabilidades aprobada.
   - **Stage 3 (Packaging):** Construcción y publicación inmutable OCI hacia Azure Container Registry (ACR) y GitHub Packages (GHCR).
   - **Stage 4 (CD):** Despliegue en la VM Azure con Nginx Gateway, microservicios .NET 10 y Redis.
2. **Dashboard de SonarQube Cloud:**
   - Visualización de la rama `devel` con estado **Passed**.
   - Cero vulnerabilidades abiertas, calificación de seguridad A y métricas de cobertura sincronizadas.

---

## 💡 Lecciones Aprendidas

1. **Tokens de Análisis vs Tokens de Servicio en DevSecOps:**  
   Los tokens dedicados únicamente a `Execute Analysis` son ideales para agentes efímeros de escaneo, pero las tareas de compuerta (*Quality Gate Gates/Publish*) requieren privilegios de lectura (`Browse`). Al configurar Service Connections para orquestadores CI/CD, se debe utilizar un **User Token** o un **Scoped Organization Token** con permisos de lectura.
2. **Sincronización de Rama Predeterminada:**  
   Herramientas externas de calidad como SonarQube Cloud asumen convencionalmente la rama `main`. En repositorios donde el flujo de integración ocurre sobre `devel`, es imperativo renombrar la Main Branch en la plataforma para no incurrir en bloqueos por análisis de ramas secundarias.
3. **Resiliencia ante Límites de Planes y Licenciamiento:**  
   Los pipelines de CI/CD deben ser resilientes: compuertas de calidad no indispensables en ramas de release o tags no deben transformarse en un punto único de falla (SPOF) que impida despliegues críticos a producción.
