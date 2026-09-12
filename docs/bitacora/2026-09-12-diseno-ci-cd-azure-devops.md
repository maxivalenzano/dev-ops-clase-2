# 🚀 2026-09-12: Diseño e Implementación de CI/CD en Azure DevOps y Versionado Semántico

**Fecha**: 2026-09-12  
**Hito**: Diseño de arquitectura de Integración y Entrega Continua (CI/CD) con **Azure DevOps Pipelines**, automatización de Versionado Semántico (SemVer) mediante Conventional Commits, construcción de artefactos OCI en Azure Container Registry (ACR) y despliegue continuo en VM Linux IaaS.

---

## 🎯 Objetivos de la sesión
- Desmitificar la automatización: construir el camino con control total (sin "magia negra"), entendiendo cada etapa del ciclo de vida DevOps.
- Diseñar un pipeline declarativo multi-stage (`azure-pipelines.yml`) que separe limpiamente las responsabilidades de **Integración Continua (CI)** y **Despliegue Continuo (CD)**.
- Implementar una estrategia de **Versionado Semántico (SemVer)** determinístico y automatizado basado en la convención de mensajes Git (**Conventional Commits**).
- Eliminar antipatrones de seguridad (evitar llaves SSH hardcodeadas o credenciales en texto plano) usando **Service Connections** y agentes seguros de Azure DevOps.
- Automatizar la actualización del clúster de microservicios en la VM Linux (`Standard_B2als_v2`) mediante Docker Compose con verificación de salud (*Smoke Testing*).

---

## 🏛️ Arquitectura del Pipeline Multi-Stage

```
 +-----------------------------------------------------------------------------------+
 |                             AZURE DEVOPS PIPELINE                                 |
 +-----------------------------------------------------------------------------------+
                                           |
                                           v
   [ STAGE 1: VERSIONING ] 
   - Analiza historial Git desde el último release.
   - Calcula siguiente versión SemVer (MAJOR, MINOR o PATCH).
   - Exporta variable $(SEMVER_TAG) para los stages siguientes.
                                           |
                                           v
   [ STAGE 2: CI - BUILD & CONTAINERIZE ]
   +---------------------------------------+---------------------------------------+
   |              BACKEND (.NET 10)        |          FRONTEND (REACT 18)          |
   | - Compilación y tests unitarios       | - Instalación de dependencias         |
   | - Docker build (.NET Alpine)          | - Vite build y linter                 |
   | - Tag: acr.../backend:$(SEMVER_TAG)   | - Docker build (Nginx SPA)            |
   |                                       | - Tag: acr.../frontend:$(SEMVER_TAG)  |
   +---------------------------------------+---------------------------------------+
                                           |
                                           v
   [ PUBLICACIÓN EN ACR ]
   - Push autenticado vía Service Connection hacia acrdevopsvalenzano.azurecr.io
                                           |
                                           v
   [ STAGE 3: CD - DEPLOY TO AZURE VM ]
   - Conexión al entorno de despliegue (Environment / VM).
   - Inyección del nuevo tag en variables de compose.yaml.
   - Pull de imágenes frescas desde ACR.
   - Ejecución atómica: `docker compose up -d --remove-orphans`.
   - Smoke Test de verificación contra Nginx (HTTP 200).
```

---

## 🛠️ Fundamentos y Decisiones Técnicas

### 1. ¿Por qué SemVer no es automático "por defecto"?
Una máquina no puede inferir la intención arquitectónica de un cambio de código. La única forma de automatizarlo rigurosamente es establecer un contrato:
- `fix: ...` -> Incrementa **PATCH** (ej: `2.0.0` -> `2.0.1`). Bug fixes sin cambios de API.
- `feat: ...` -> Incrementa **MINOR** (ej: `2.0.0` -> `2.1.0`). Nuevas funcionalidades compatibles hacia atrás.
- `feat!: ...` o `BREAKING CHANGE:` -> Incrementa **MAJOR** (ej: `2.0.0` -> `3.0.0`). Ruptura del contrato de API.

### 2. Service Connection: Seguridad sin llaves expuestas
Para que Azure DevOps interactúe con el registro (ACR) y la máquina virtual (VM), no se deben almacenar passwords en el repositorio. Se configuran **Service Connections** en el proyecto de Azure DevOps:
- **Docker Registry Service Connection**: Permite a los agentes de compilación hacer `docker login` y `docker push` hacia `acrdevopsvalenzano.azurecr.io` de manera segura y temporal.
- **Environment Virtual Machine / SSH Service Connection**: Permite delegar la orquestación del despliegue directamente en la VM `vm-dev-ops`.

### 3. Principio de Inmutabilidad y Cero Residuos
El servidor no compila código ni instala herramientas de desarrollo (ni Node.js ni el SDK de .NET están en el host Ubuntu). La VM solo ejecuta contenedores Docker inmutables descargados desde el registro privado.

---

## 📋 Checklist de Puesta en Marcha (Paso a Paso)

1. [ ] **Azure DevOps Portal**:
   - Crear Organización y Proyecto (o vincular con el repositorio GitHub).
   - Crear Service Connection para **ACR** (`acrdevopsvalenzano`).
   - Crear Environment para la **VM** (`vm-dev-ops`).
2. [ ] **Definición del Pipeline**:
   - Crear `azure-pipelines.yml` en la raíz del repositorio.
   - Probar validación de sintaxis YAML.
3. [ ] **Ejecución y Pruebas**:
   - Realizar commit con formato Conventional Commit.
   - Observar la ejecución de los stages en tiempo real.
   - Verificar imágenes en ACR con los nuevos tags generados.
   - Verificar respuesta HTTP de la VM en `http://68.211.137.116`.

---

## 📌 Próximos Pasos
- Completar la vinculación en el portal de Azure DevOps y ejecutar el primer pipeline end-to-end.
