# 🛡️ TP 1 - Etapa 5: CI con Análisis Estático de Seguridad (SAST), SonarQube Cloud y Badges

**Fecha:** 2026-09-14  
**Rama:** `implement_stage_five`  
**Autor:** Maxi Valenzano  
**Componentes involucrados:** Azure Pipelines (`azure-pipelines.yml`), SonarQube Cloud, Trivy Scanner, xUnit Tests, `README.md`.

---

## 🎯 Objetivo de la Etapa

Evolucionar la fase de **Integración Continua (CI)** del proyecto hacia un estándar integral de **DevSecOps**, incorporando:
1. Análisis estático de seguridad de código (**SAST**) y calidad mediante **SonarQube Cloud**.
2. Compuerta de calidad automatizada (**Quality Gate**) que evalúe métricas de bugs, vulnerabilidades, code smells y cobertura de tests.
3. Auditoría complementaria de vulnerabilidades en dependencias y `Containerfile` con **Trivy**.
4. Recolección y publicación dual de métricas de cobertura de pruebas (.NET 10 con Coverlet en formatos `cobertura` y `opencover`).
5. Gobernanza y visibilidad continua mediante **badges oficiales dinámicos** en `README.md`.

---

## 🏗️ Arquitectura de Seguridad y Flujo en CI

```text
[ Agente Azure Pipelines (Ubuntu) ]
                │
                ▼
      [ 1. SonarCloudPrepare ] ──> Configura análisis para 'maxivalenzano_DevOps'
                │
                ▼
      [ 2. dotnet build ] ──────> Compilación instrumentada (.NET 10 Release)
                │
                ▼
      [ 3. dotnet test ] ───────> 42 tests xUnit
                │                 ├─ test_results.trx (VSTest para pestaña Tests)
                │                 ├─ coverage.cobertura.xml (Azure DevOps Code Coverage)
                │                 └─ coverage.opencover.xml (SonarQube Cloud Coverage)
                ▼
      [ 4. SonarCloudAnalyze ] ──> Escaneo SAST de código C#, seguridad y cobertura
                │
                ▼
      [ 5. SonarCloudPublish ] ──> Evaluación del Quality Gate (bloquea si no cumple)
                │
                ▼
      [ 6. Trivy Scanner ] ─────> Auditoría de CVEs en Containerfiles y dependencias
                │
                ▼
      [ 7. Build & Push OCI ] ──> Construcción de contenedores hacia ACR y GHCR
```

---

## ⚙️ Decisiones Técnicas e Implementación

### 1. Integración de SonarQube Cloud en Azure DevOps
- **Extensión oficial**: Se instaló la extensión `SonarSource.sonarcloud` desde el Visual Studio Marketplace.
- **Service Connection**: Se configuró una conexión de tipo *SonarQube Cloud* llamada `SonarCloud` vinculada al token de autenticación de la organización `maxivalenzano`.
- **Scanner Mode `MSBuild`**: El escáner se acopla a la compilación de la solución .NET, permitiendo inspeccionar la sintaxis, tipos y dependencias a bajo nivel.

### 2. Formatos de Cobertura Duales con Coverlet
SonarQube Cloud requiere el formato `opencover` para el mapeo línea a línea de código C#, mientras que la tarea nativa `PublishCodeCoverageResults@2` de Azure DevOps consume el estándar `cobertura`.  
Se configuró `dotnet test` pasando ambos formatos simultáneamente mediante parámetros de recolección de Coverlet:
```bash
dotnet test tests/Backend.Tests/Backend.Tests.csproj \
  --configuration Release \
  --logger "trx;LogFileName=test_results.trx" \
  --collect:"XPlat Code Coverage" \
  -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=opencover,cobertura
```

### 3. Configuración de `azure-pipelines.yml`
Se actualizaron los pasos del Stage 2 (`CI`):
* **`SonarCloudPrepare@3`**:
  * `organization`: `maxivalenzano`
  * `projectKey`: `maxivalenzano_DevOps`
  * `extraProperties`: configuración de exclusión para artefactos temporales y referencias a los reportes de cobertura TRX y OpenCover.
* **`SonarCloudAnalyze@3`**: Ejecución de las reglas de análisis estático.
* **`SonarCloudPublish@3`**: Bloqueo o aprobación según el Quality Gate configurado en la plataforma.
* **Auditoría Trivy**:
  * `trivy fs --severity HIGH,CRITICAL --exit-code 0 .` para advertir sobre vulnerabilidades de librerías del sistema o paquetes de terceros sin detener de forma arbitraria el laboratorio formativo.

### 4. Visibilidad y Gobernanza en `README.md`
Se reemplazaron los badges estáticos por badges dinámicos con consultas directas a las APIs de Azure DevOps y SonarCloud:
- **Build Status**: Consulta en vivo de la rama `devel`.
- **Quality Gate Status**: Evaluación de la calidad del código.
- **Security Rating**: Calificación de seguridad de SonarCloud.
- **Vulnerabilities**: Contador de vulnerabilidades abiertas.
- **Coverage**: Porcentaje de líneas cubiertas por los 42 tests unitarios.

---

## ✅ Resultados y Criterios de Aceptación
1. **Pipeline Automatizado**: El CI ahora valida compilación, pruebas xUnit, cobertura, análisis estático y Quality Gate antes de generar imágenes OCI.
2. **Dashboard Centralizado**: Los resultados se visualizan tanto en Azure DevOps (pestañas *Tests* y *Code Coverage*) como en SonarQube Cloud (dashboard del proyecto `maxivalenzano_DevOps`).
3. **Cumplimiento del Plan**: Finalización satisfactoria de los requisitos de la **Etapa 5** de `PLAN_TP1.md`.
