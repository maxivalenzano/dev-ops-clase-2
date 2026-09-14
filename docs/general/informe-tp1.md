# 📄 Trabajo Práctico Nº 1: Aplicación Web, API y Servicio Redis Contenerizados
## DevOps – Cultura, Herramientas y Procesos | UTN FRRe | Ciclo Lectivo 2026

---

### 🏛️ Datos Institucionales y Académicos

* **Institución:** Universidad Tecnológica Nacional – Facultad Regional Resistencia (UTN FRRe)
* **Carrera:** Ingeniería en Sistemas de Información
* **Asignatura:** DevOps – Cultura, Herramientas y Procesos
* **Docente Titular:** Prof. Ing. Jose A. Fernandez
* **Estudiante:** Maximiliano Nicolas Valenzano
* **Legajo:** 21664
* **Fecha de Presentación y Coloquio:** Lunes 14 de Septiembre de 2026

---

### 🌐 Accesos Directos al Ecosistema del Proyecto

| Recurso | Enlace Directo | Descripción |
| :--- | :--- | :--- |
| **Repositorio GitHub** | [maxivalenzano/dev-ops-clase-2](https://github.com/maxivalenzano/dev-ops-clase-2) | Código fuente, Containerfiles, pipelines y documentación |
| **Aplicación en Vivo (Producción Cloud)** | [http://devops-maxivalenzano.com](http://devops-maxivalenzano.com) | Despliegue en Azure VM con dominio propio (Alt: `http://68.211.137.116`) |
| **Panel de Gestión Visual (Portainer CE)** | [http://devops-maxivalenzano.com:9000](http://devops-maxivalenzano.com:9000) | Observabilidad y administración en tiempo real del clúster de contenedores |
| **Pipeline Multi-Stage (Azure DevOps)** | [Pipeline Oficial en Azure DevOps](https://dev.azure.com/maxivalenzano/DevOps/_build/latest?definitionId=1&branchName=devel) | Pipeline CI/CD automatizado en 4 etapas con SemVer dinámico |
| **Quality Gate & SAST (SonarQube Cloud)** | [Dashboard de SonarCloud](https://sonarcloud.io/summary/new_code?id=maxivalenzano_DevOps) | Análisis Estático de Seguridad, Vulnerabilidades, Deuda Técnica y Cobertura |
| **Documentación Web (VitePress)** | [Docs & Bitácora en Vivo](http://devops-maxivalenzano.com/docs/) | Bitácora técnica cronológica con más de 20 entradas detalladas |

---

## 1. Resumen Ejecutivo e Introducción

El presente trabajo práctico implementa una solución completa basada en la cultura, herramientas y principios de **DevOps y DevSecOps**. El objetivo primordial es el diseño, contenerización, orquestación, integración continua (CI), análisis estático de seguridad (SAST) y despliegue continuo (CD) de un sistema distribuido multicapa en alta disponibilidad.

### 💡 Justificación Tecnológica: Adopción de Microsoft Azure & Azure DevOps
En concordancia con las pautas de la cátedra que permiten la sustitución justificada de herramientas estándar (como GitHub Actions) por plataformas de nivel empresarial, **se implementó el ciclo de vida completo mediante el stack de Microsoft Azure y Azure DevOps Pipelines**:
1. **Simulación de Entorno Corporativo Real:** Azure DevOps provee capacidades nativas de nivel enterprise tales como gestión de artefactos OCI en Azure Container Registry (ACR), entornos de despliegue con agentes pull-based (`Environments`), compuertas de aprobación (*Approvals and Quality Gates*), y tableros ágiles vinculados (Azure Boards con Process Template *Agile* y 107 Work Items trazados).
2. **Aprovechamiento de Créditos de Estudiante:** Se capitalizó la suscripción académica de Azure for Students para aprovisionar una máquina virtual Linux Ubuntu (`Standard_B2als_v2`), IP pública estática, DNS personalizado con IONOS (`devops-maxivalenzano.com`), registros privados OCI y un cluster visual con Portainer CE.
3. **Interoperabilidad Híbrida:** A pesar de ejecutar la orquestación en Azure, se diseñó una integración bidireccional no bloqueante con GitHub: cada pipeline exitoso en Azure publica artefactos duales en Azure Container Registry (ACR) y GitHub Container Registry (GHCR), crea GitHub Releases automáticos con Changelog dinámico y actualiza los estados de despliegue mediante la GitHub Deployments API.

---

## 2. Matriz de Cumplimiento de Requerimientos (Rúbrica de Evaluación)

| # | Requerimiento de la Cátedra | Estado | Evidencia de Implementación |
| :---: | :--- | :---: | :--- |
| **1** | **Apps contenerizadas (Web / API)** | ✅ **Cumplido** | `frontend/Containerfile` (Multi-stage Node.js + Nginx Alpine) y `backend/Containerfile` (Multi-stage .NET 10 SDK + Runtime Chiseled/Alpine). |
| **2** | **Conexión de API contra Redis o DB** | ✅ **Cumplido** | Integración asíncrona de `StackExchange.Redis` en backend .NET 10 (`TaskService.cs`). Solo la API accede a Redis; la web consume exclusivamente la API REST. |
| **3** | **Publicación en Registry vía CI** | ✅ **Cumplido** | Azure Pipelines (Stage 3 `Packaging`) compila y publica imágenes inmutables con tags SemVer en **Azure Container Registry (ACR)** y sincroniza con **GitHub Packages (GHCR)**. |
| **4** | **Deploy en servicio Cloud desde Registry** | ✅ **Cumplido** | Azure VM Ubuntu con agente pull-based (`devops-vm-env`). El pipeline ejecuta `docker compose pull` desde ACR y actualiza contenedores sin intervención manual. |
| **5** | **Entorno local: proxy y réplicas** | ✅ **Cumplido** | `compose.yaml` define Nginx Gateway, 3 réplicas de frontend, 3 réplicas de backend, Redis con volumen persistente y Portainer CE. Soporte adicional para Podman Pods locales (`./scripts/run-pod.ps1`). |
| **6** | **Nube: instancia funcional publicada** | ✅ **Cumplido** | Despliegue productivo 100% operativo en `http://devops-maxivalenzano.com` y `http://68.211.137.116`. |
| **7** | **Réplicas en Cloud (Mejora Opcional)** | 🌟 **Superado** | Se desplegó la arquitectura completa de **3 réplicas de backend y 3 réplicas de frontend** también en la nube, con balanceo Round-Robin activo. |
| **8** | **CI con Tests Unitarios y SAST + Badges** | ✅ **Cumplido** | Azure Pipelines (Stage 2): 42 pruebas unitarias (.NET 10 xUnit + Moq) con cobertura dual, escaneo estático de vulnerabilidades con **SonarQube Cloud SAST**, auditoría de dependencias con **Trivy Scanner**, Quality Gate bloqueante y badges activos en el README. |
| **9** | **Proxy Reverso con 3 nodos y tolerancia a fallos** | ✅ **Cumplido** | Nginx con `upstream backend_cluster` (3 servidores), balanceo Round-Robin, `proxy_next_upstream` tolerante a caídas y reintentos automáticos ante error 500/502/503/504. |

---

## 3. Arquitectura del Sistema

### 3.1. Diagrama de Arquitectura Distribuida (Local y Nube)

```text
                                       🌐 CLIENTE / NAVEGADOR WEB
                             (http://devops-maxivalenzano.com | localhost)
                                                    │
                                                    ▼
                             ┌──────────────────────────────────────────────┐
                             │       NGINX REVERSE PROXY & GATEWAY          │
                             │              (Puerto 80:80)                  │
                             │   - Balanceador de Carga Round-Robin         │
                             │   - Timeouts estrictos: 5s (Test 504)        │
                             │   - Failover automático (proxy_next_upstream)│
                             └──────────────┬────────────────┬──────────────┘
                                            │                │
                      Ruta / (Tráfico Web)  │                │  Ruta /api/ (Tráfico REST)
                                            ▼                ▼
                     ┌───────────────────────────┐      ┌───────────────────────────┐
                     │ upstream frontend_cluster │      │ upstream backend_cluster  │
                     └─────────────┬─────────────┘      └─────────────┬─────────────┘
          ┌────────────────────────┼────────────────────────┐         │
          │                        │                        │         │
          ▼                        ▼                        ▼         │
   [ frontend-1 ]           [ frontend-2 ]           [ frontend-3 ]   │
   (React 18 SPA)           (React 18 SPA)           (React 18 SPA)   │
   Nginx Port: 8081         Nginx Port: 8081         Nginx Port: 8081 │
   CPU: 0.25 | RAM: 64M     CPU: 0.25 | RAM: 64M     CPU: 0.25 | RAM: 64M
                                                                      │
          ┌───────────────────────────────────────────────────────────┴────────────────┐
          │                                            │                               │
          ▼                                            ▼                               ▼
   [ backend-1 ]                                [ backend-2 ]                   [ backend-3 ]
   (.NET 10 Minimal API)                        (.NET 10 Minimal API)           (.NET 10 Minimal API)
   Port: 3000                                   Port: 3000                      Port: 3000
   Nodo: backend-dotnet-1                       Nodo: backend-dotnet-2          Nodo: backend-dotnet-3
   CPU: 0.5 | RAM: 128M                         CPU: 0.5 | RAM: 128M            CPU: 0.5 | RAM: 128M
          │                                            │                               │
          └─────────────────────────────┬──────────────┴───────────────────────────────┘
                                        │ (Conexión TCP asíncrona / StackExchange.Redis)
                                        ▼
                                 ┌──────────────┐
                                 │ lab-redis    │
                                 │ Redis 7      │
                                 │ Port: 6379   │
                                 └──────┬───────┘
                                        │
                                        ▼ (Almacenamiento Persistente en Disco)
                             ┌──────────────────────┐
                             │ Volumen: redis-data  │
                             └──────────────────────┘
```

Adicionalmente, se ejecuta en la misma red de aislamiento el contenedor de observabilidad visual:
* **`lab-portainer` (Portainer CE):** Expuesto en el puerto `9000:9000` con volumen persistente `portainer-data`, accesible en `http://devops-maxivalenzano.com:9000`.

---

## 4. Descripción Detallada de Módulos y Componentes

### 4.1. Módulo 1: Aplicación Web Frontend (React 18 SPA)
* **Tecnología:** React 18, Vite, Lucide Icons, CSS moderno responsivo.
* **Empaquetado:** *Containerfile multi-stage*. En la primera etapa (`node:22-alpine`) se descargan dependencias de forma inmutable mediante `npm ci` y se compilan los activos estáticos (`npm run build`). En la segunda etapa (`nginx:alpine`), se copia la distribución optimizada y se sirve a través de un servidor web ultraligero que incluye compresión gzip y configuración de enrutamiento SPA (`try_files $uri $uri/ /index.html`).
* **Telemetría de Doble Nivel e Identidad:** Cada réplica inyecta su nombre de contenedor mediante la cabecera HTTP personalizada `X-Frontend-Instance` y provee el endpoint `/frontend-info`. El usuario visualiza en tiempo real tanto el nodo frontend que sirvió el HTML como el nodo backend que atendió la API.
* **Doble Modo Operativo en UI:**
  1. **Tablero de Tareas Distribuido (`TaskBoard.jsx`):** Creación, toggle de estado completado y borrado de tareas con badges que identifican qué nodo creó la tarea (`createdByNode`) y qué nodo sirvió la consulta (`servedByNode`).
  2. **Laboratorio de Caos y Métricas (`ChaosLab.jsx`):** Panel interactivo para ejecutar pruebas de estrés, latencia forzada, fuga de memoria y verificación de conmutación por error en vivo.

### 4.2. Módulo 2: Microservicio Backend (.NET 10 Minimal API)
* **Tecnología:** C# sobre **.NET 10**, aprovechando Minimal APIs para lograr una huella de memoria minúscula (~25-35 MB RSS en reposo) y un rendimiento de alto throughput con I/O asíncrono puro.
* **Separación de Capas e Inyección de Dependencias:**
  * `Models/TaskItem.cs`: Modelo de dominio inmutable con validación de títulos, identificador UUID y marcas de tiempo UTC.
  * `Services/ITaskService.cs` y `Services/TaskService.cs`: Capa de persistencia desacoplada inyectada como singleton en `Program.cs`.
  * `StackExchange.Redis`: Cliente de alto desempeño con reconexión resiliente (`AbortOnConnectFail = false`, `ConnectTimeout = 2000`).
* **Seguridad de Capas:** El backend es el único componente con acceso directo a Redis. Redis no expone puertos públicos hacia Internet; la comunicación reside exclusivamente en la red interna bridge (`lab-network`).
* **Contrato REST implementado:**
  * `GET /api/tasks`: Retorna el listado completo, totalizador y la firma `servedByNode`.
  * `POST /api/tasks`: Recibe `{ "title": "..." }`, genera UUID, estampa `createdByNode: instanceName` y guarda en Redis con código `201 Created`.
  * `PUT /api/tasks/{id}/toggle`: Modifica atómicamente el estado booleano en Redis.
  * `DELETE /api/tasks/{id}`: Elimina la clave de la base en memoria (`204 No Content`).
  * `GET /api/info` y `GET /health`: Diagnóstico de salud y metadatos de instancia.
  * Endpoints de Caos: `/api/delay?ms=...`, `/api/stress/cpu`, `/api/stress/memory`, `/api/stress/memory/clear` y `/api/health/toggle`.

### 4.3. Módulo 3: Base de Datos en Memoria y Caché (Redis 7)
* **Tecnología:** `redis:7-alpine`.
* **Persistencia:** Configurado con volumen Docker persistente `redis-data` montado en `/data`. Si todos los contenedores backend, frontend o incluso el host se reinician, las tareas permanecen intactas gracias al mecanismo de instantáneas RDB/AOF de Redis.
* **El Concepto Central: "Node Signature Board":**
  * Demuestra fehacientemente el estado compartido y la naturaleza *stateless* de los microservicios backend.
  * Cuando el cliente envía `POST /api/tasks`, Nginx balancea a `backend-1`. Este nodo estampa su firma:
    ```json
    {
      "id": "c7a840e1-450f-48d6-95b1-0985c72cb612",
      "title": "Verificar tolerancia a fallos",
      "isCompleted": false,
      "createdByNode": "backend-dotnet-1",
      "createdAt": "2026-09-14T15:30:00Z"
    }
    ```
  * En la siguiente consulta `GET /api/tasks`, Nginx balancea la solicitud a `backend-3`. Este lee la información desde Redis y responde:
    ```json
    {
      "servedByNode": "backend-dotnet-3",
      "totalCount": 1,
      "tasks": [ ... ]
    }
    ```
  * La interfaz gráfica colorea los badges de manera distintiva (Azul para nodo 1, Verde para nodo 2, Naranja para nodo 3), ofreciendo una demostración visual incontrastable para la cátedra.

### 4.4. Módulo 4: Nginx Gateway y Proxy Reverso
* **Balanceo de Carga:** Configurado bajo la directiva `upstream` en modo **Round-Robin** simétrico.
* **Tolerancia a Caídas y Failover (Zero Downtime):**
  ```nginx
  proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
  proxy_next_upstream_tries 3;
  ```
  Si una de las réplicas backend arroja un error interno (500), se desconecta repentinamente o es eliminada por el sistema operativo, Nginx reenvía la petición al siguiente nodo sano de forma transparente en menos de 10 milisegundos, sin que el cliente experimente ningún fallo.
* **Respuestas de Diagnóstico en JSON:** En lugar de páginas HTML genéricas de Nginx, se programaron interceptores de error (`custom_502.json` y `custom_504.json`) que retornan respuestas JSON estructuradas indicando el motivo exacto del evento para facilitar la observabilidad.

---

## 5. Implementación del Pipeline CI/CD y DevSecOps en Azure Pipelines

El pipeline automatizado (`azure-pipelines.yml`) consta de **4 Stages secuenciales, modulares e independientes**, siguiendo el principio de diseño de **Fail-Fast**:

```text
┌───────────────────────┐
│ 1. Versioning         │  --> Cálculo automático de SemVer (Conventional Commits)
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│ 2. Quality Gate & SAST│  --> Tests Unitarios xUnit + SonarQube Cloud SAST + Trivy
└──────────┬────────────┘      (Si falla la cobertura o seguridad, SE ABORTA EL PIPELINE)
           ▼
┌───────────────────────┐
│ 3. Packaging          │  --> Construcción inmutable OCI + Push a ACR y GHCR
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│ 4. CD (Deploy a VM)   │  --> Pull-based CD en Azure VM + Smoke Tests + GitHub Releases
└───────────────────────┘
```

### 5.1. Stage 1: Versionado Semántico Dinámico (SemVer)
* **Mecanismo:** Analiza el historial completo de Git (`fetchDepth: 0`) y la sintaxis de *Conventional Commits*:
  * Prefijos `feat!:` o `BREAKING CHANGE:` $\rightarrow$ Incremento de versión **MAJOR**.
  * Prefijo `feat:` $\rightarrow$ Incremento de versión **MINOR**.
  * Prefijos `fix:`, `perf:`, `refactor:` $\rightarrow$ Incremento de versión **PATCH**.
* **Resultado:** Genera una variable inmutable `SEMVER_TAG` (ej. `2.1.2`) que bautiza la ejecución del pipeline y etiqueta de forma idéntica las imágenes de contenedor y los releases de Git.

### 5.2. Stage 2: Quality Gate & SAST (Pruebas Unitarias y Seguridad Estática)
Desacoplado en dos jobs paralelos en agentes `ubuntu-latest`:
1. **Job Backend (`BackendQuality`):**
   * Compilación estricta en modo `Release`.
   * **Ejecución de 42 pruebas unitarias (.NET 10 xUnit):**
     * `TaskItemTests.cs`: Integridad de modelo, validaciones de argumentos nulos o en blanco.
     * `TaskServiceTests.cs`: Pruebas de lógica de negocio aislando Redis mediante **Moq** (`Mock<IDatabase>`).
     * `HealthEndpointTests.cs` y `ChaosEndpointTests.cs`: Comportamiento de endpoints de salud y pruebas de estrés.
   * **Recolección Dual de Cobertura de Código:** Generación de formatos `OpenCover` (para SonarQube Cloud) y `Cobertura` (para la pestaña nativa de Code Coverage de Azure DevOps).
   * **Análisis SAST con SonarQube Cloud (`SonarCloudAnalyze@4`):**
     * Escaneo de vulnerabilidades, *code smells* y puntos críticos de seguridad (*Security Hotspots*).
     * **Compuerta de Calidad Bloqueante (`SonarCloudPublish@4`):** Evalúa el Quality Gate oficial. Si la cobertura no cumple el umbral o se detectan vulnerabilidades de severidad crítica, la tarea falla y detiene el flujo antes de generar cualquier artefacto.
2. **Job Frontend y Contenedores (`FrontendAndSecurity`):**
   * Validación de empaquetado del cliente React 18 con `npm ci` y `npm run build`.
   * **Auditoría SAST con Trivy Scanner:** Escaneo estático del sistema de archivos, dependencias de Node y Containerfiles en busca de CVEs clasificados como `HIGH` o `CRITICAL`.

### 5.3. Stage 3: Packaging (Construcción y Publicación OCI)
* Autenticación segura mediante Service Connection (`acrdevopsvalenzano-sc`) sin credenciales expuestas en texto plano.
* Construcción multi-stage de imágenes para `backend` y `frontend`.
* Etiquetado dual inmutable: `:$(SEMVER_TAG)` y `:latest`.
* Publicación simultánea en:
  * **Azure Container Registry (ACR):** `acrdevopsvalenzano.azurecr.io/backend` y `/frontend`.
  * **GitHub Container Registry (GHCR):** `ghcr.io/maxivalenzano/dev-ops-backend` y `/dev-ops-frontend`.

### 5.4. Stage 4: Entrega Continua (CD) en Azure VM
* **Arquitectura de Agente Pull-based:** Se configuró un recurso de tipo *Virtual Machine* en el *Environment* `devops-vm-env` de Azure DevOps. La VM consulta hacia Azure DevOps mediante canales seguros salientes HTTPS (puerto 443), lo cual **elimina la necesidad de abrir puertos SSH (22) hacia Internet**, reduciendo a cero la superficie de ataque por fuerza bruta.
* **Proceso de Actualización:**
  1. Descarga de nuevas imágenes desde ACR (`docker compose pull`).
  2. Actualización de servicios sin downtime (`docker compose up -d --remove-orphans`).
  3. Reinicio atómico de Nginx para refrescar la resolución DNS interna de Docker.
  4. **Smoke Tests Automatizados:** Ejecución de `curl -fsS http://localhost/` y `curl -fsS http://localhost/api/info` para certificar la respuesta `HTTP 200 OK`.
  5. **Sincronización con GitHub:** Creación automática del release en GitHub con notas extraídas de Git, actualización de la URL oficial en el repositorio y notificación de estado `success` a la GitHub Deployments API.

---

## 6. Pruebas y Validación de Alta Disponibilidad (Chaos Engineering)

Para dar respuesta rigurosa al requerimiento de *“demostrar balanceo y tolerancia a la caída de una instancia”*, se programaron y validaron 5 experimentos concretos:

### 6.1. Experimento 1: Balanceo de Carga Round-Robin
* **Procedimiento:** Desde el panel web, se disparó una ráfaga de 50 peticiones concurrentes a la API.
* **Resultado Observado:** Nginx distribuyó el tráfico de manera equitativa entre los nodos (`backend-1`: ~17 requests, `backend-2`: ~16 requests, `backend-3`: ~17 requests). El gráfico de barras del frontend reflejó la alternancia perfecta en tiempo real.

### 6.2. Experimento 2: Tolerancia a Caídas y Failover en Vivo
* **Procedimiento:** Con el sistema en pleno funcionamiento, se forzó la detención abrupta del nodo principal mediante terminal:
  ```bash
  docker compose stop backend-1
  ```
* **Resultado Observado:**
  1. Las peticiones enviadas a continuación fueron absorbidas instantáneamente por `backend-2` y `backend-3`.
  2. **Tiempo de inactividad percibido por el usuario: 0 ms**.
  3. Todas las tareas creadas previamente por `backend-1` continuaron listándose con total normalidad en la pantalla, dado que residen en Redis (`redis-data`) y no en la memoria volátil del contenedor apagado.

### 6.3. Experimento 3: Timeout de Gateway (`504 Gateway Timeout`)
* **Procedimiento:** Nginx fue configurado con `proxy_read_timeout 5s`. Desde el módulo de caos, se disparó una petición al endpoint `/api/delay?ms=6000` (6 segundos).
* **Resultado Observado:** A los 5000 ms exactos, Nginx interrumpió la conexión y retornó el error estructurado `504 Gateway Timeout`, validando las políticas de contención ante cuellos de botella de red o servicios colgados.

### 6.4. Experimento 4: Límite de Memoria y Activación de OOM Killer
* **Procedimiento:** Cada contenedor backend tiene un límite estricto en Compose de `128M` (`memory: 128M`). Se invocó reiteradamente el endpoint `/api/stress/memory?mb=50` forzando la asignación física de bloques de memoria.
* **Resultado Observado:** Al superar los 128 MB, el kernel de Linux invocó el **OOM Killer** y dio de baja el proceso con código de salida **Exit Code 137**. Nginx detectó la caída del socket y redirigió la petición al nodo hermano sin afectar la navegación del usuario.

### 6.5. Experimento 5: Demostración de las 42 Pruebas Unitarias
* **Procedimiento:** Ejecución en local y en el agente de Azure Pipelines:
  ```bash
  dotnet test tests/Backend.Tests/Backend.Tests.csproj
  ```
* **Resultado Observado:**
  ```text
  Test run for Backend.Tests.dll (.NETCoreApp,Version=v10.0)
  Passed! - Failed: 0, Passed: 42, Skipped: 0, Total: 42, Duration: 15 s
  ```
  Validación al 100% de la lógica de negocio, mocks de Redis, resiliencia y endpoints REST.

---

## 7. Dificultades Encontradas y Soluciones Técnicas (Troubleshooting)

A lo largo del ciclo de vida del proyecto surgieron desafíos técnicos complejos, los cuales fueron documentados detalladamente en la bitácora del repositorio:

### ⚠️ Dificultad 1: Caché DNS Interna en Nginx causaba Error 502 Bad Gateway tras el Despliegue
* **Contexto:** En los primeros despliegues automáticos mediante CD, tras ejecutarse `docker compose up -d`, el Smoke Test fallaba arrojando código `HTTP 502 Bad Gateway`.
* **Causa Raíz:** Los contenedores recreados recibían nuevas direcciones IP dinámicas asignadas por la red bridge de Docker. Nginx resolvía los nombres de host (`backend-1`, `backend-2`, etc.) una sola vez durante su inicialización y almacenaba las IPs en su caché estática. Al cambiar las IPs de los backends, Nginx intentaba comunicarse con sockets inexistentes.
* **Solución Técnica:** Se incorporó en el Stage 4 del pipeline el comando explícito `docker compose restart nginx` inmediatamente después del levantamiento de contenedores. Esto fuerza a Nginx a recargar su tabla de resolución DNS interna, eliminando completamente los errores 502 posteriores al despliegue.

### ⚠️ Dificultad 2: Error 403 Forbidden en SonarQube Cloud y Gobernanza de Ramas
* **Contexto:** Al integrar la tarea `SonarCloudPublish@4` en Azure Pipelines, la tarea fallaba con `HTTP 403 Forbidden` al consultar la API REST de SonarQube Cloud.
* **Causa Raíz:** El token generado en SonarCloud poseía únicamente permisos de ejecución de análisis (*Execute Analysis*), careciendo de privilegios de lectura (*Browse*) requeridos por la tarea de Azure DevOps para consultar el resultado del Quality Gate. Adicionalmente, el plan Free de SonarCloud bloquea el análisis de ramas múltiples en repositorios privados si no coinciden con la rama principal configurada.
* **Solución Técnica:** Se regeneró el token con permisos globales de lectura/análisis, se configuró la rama `devel` como *Main Branch* de referencia en el portal de SonarCloud y se incorporaron directivas condicionales en `azure-pipelines.yml` para ejecutar el análisis SAST de manera blindada en ramas de integración sin bloquear tags de lanzamiento.

### ⚠️ Dificultad 3: Deadlock en Aprobaciones de CD en Azure DevOps Environments
* **Contexto:** Al configurar compuertas de aprobación manual (*Approvals*) sobre el entorno `devops-vm-env`, los pipelines quedaban suspendidos indefinidamente en estado pendiente.
* **Causa Raíz:** Por diseño de seguridad corporativo, Azure DevOps deshabilita por defecto que el mismo usuario que dispara un commit o ejecuta un build pueda aprobar su propio despliegue (*Prevent approval by requester*).
* **Solución Técnica:** Se ajustaron los permisos de gobernanza en el panel de Azure DevOps marcando la casilla *"Allow approvers to approve their own runs"*, permitiendo un flujo de entrega ágil adecuado para equipos de desarrollo unipersonales y proyectos académicos.

### ⚠️ Dificultad 4: Timeout de Inicialización en Portainer CE
* **Contexto:** Al desplegar Portainer Community Edition por primera vez en la VM de Azure, el contenedor se auto-bloqueaba mostrando el mensaje de seguridad: *"Portainer instance timed out for security purposes. To re-enable, restart the container"*.
* **Causa Raíz:** Por directiva de seguridad, Portainer exige crear la cuenta de administrador dentro de los primeros 5 minutos desde su primer arranque. Si no se accede a tiempo, el demonio deshabilita el asistente web.
* **Solución Técnica:** Se configuró la regla de entrada en el Network Security Group (NSG) de Azure abriendo el puerto 9000 hacia Internet, se reinició el contenedor con `docker compose restart portainer` y se estableció una clave robusta superior a 12 caracteres, habilitando la consola visual definitiva para el coloquio.

---

## 8. Propuesta de Mejoras Futuras (Visión Arquitectónica Enterprise)

Para demostrar visión de ingeniería de software avanzada y evolución de sistemas ante la cátedra, se formularon las siguientes líneas de evolución:

### 8.1. Evolución a Arquitectura Híbrida: PostgreSQL (Persistencia ACID) + Redis (Caché con Patrón Cache-Aside)
Actualmente, el sistema utiliza Redis tanto como almacén de estado como caché en memoria. La evolución natural hacia un entorno bancario o transaccional de misión crítica consiste en desacoplar ambas responsabilidades mediante el patrón **Cache-Aside / Write-Through**:

```text
                           Host / Navegador
                                  │
                                  ▼
                         [ Nginx Gateway ]
                        /        │        \ (Balanceo Round-Robin)
                       ▼         ▼         ▼
                 [Backend 1] [Backend 2] [Backend 3] (.NET 10)
                       │         │         │
              ┌────────┴─────────┼─────────┴────────┐
              │                  │                  │
              ▼ (Paso 1: ¿Hit?)  ▼                  ▼ (Paso 2: Si Miss o Write)
      ┌───────────────┐                     ┌───────────────────┐
      │ SERVICIO      │                     │ SERVICIO          │
      │ REDIS         │  ── Cache Miss ──>  │ POSTGRESQL        │
      │ (Caché en RAM)│  <── Guardo acá ──  │ (Datos en Disco)  │
      └───────────────┘                     └───────────────────┘
              │                                     │
              ▼                                     ▼
      [ redis-data ]                         [ pg-data ]
```

1. **Roles y Responsabilidades:**
   * **PostgreSQL (System of Record):** Persistencia relacional duradera en disco con garantías ACID estrictas, transacciones, soporte de claves foráneas y auditoría mediante Write-Ahead Logging (WAL).
   * **Redis (Performance Booster):** Respuestas sub-milisegundo (< 1 ms) para lecturas de alto tráfico directamente desde RAM, reduciendo hasta un 80% las operaciones de E/S en disco sobre PostgreSQL.
2. **Flujo Operativo en Backend (.NET 10):**
   * **Lectura (`GET /api/tasks`):** La API consulta primero a Redis. Si la clave existe (**Cache Hit**), la devuelve al instante. Si no existe (**Cache Miss**), consulta la base relacional PostgreSQL, actualiza la caché en Redis con un tiempo de vida (TTL, ej. 10 minutos) y responde al cliente.
   * **Escritura (`POST` / `PUT` / `DELETE`):** Se guarda la transacción en PostgreSQL y se invalida la clave correspondiente en Redis (`DEL tasks`), asegurando consistencia eventual estricta.

### 8.2. Alta Disponibilidad en Redis (Redis Sentinel o Redis Cluster)
Para eliminar el punto único de fallo (SPOF) en la capa de datos en memoria, se proyecta implementar **Redis Sentinel** con una arquitectura de un nodo Primario y dos Réplicas. Sentinel monitorea los procesos y, en caso de caída del Primario, promociona automáticamente una réplica a maestro y notifica a las instancias de .NET mediante eventos Pub/Sub.

### 8.3. Automatización de Certificados SSL/TLS con Let's Encrypt (HTTPS)
Incorporar un contenedor complementario con `certbot` para solicitar y renovar automáticamente certificados X.509 de Let's Encrypt para `devops-maxivalenzano.com`, redirigiendo todo el tráfico del puerto 80 al puerto seguro 443 con cifrado TLS 1.3 y cabeceras HSTS (*HTTP Strict Transport Security*).

### 8.4. Migración a Orquestación Gestionada (Kubernetes - AKS / Azure Container Apps)
Evolucionar desde Docker Compose en máquina virtual individual hacia **Azure Container Apps (ACA)** o un clúster de **Azure Kubernetes Service (AKS)**, permitiendo escalado horizontal automático de Pods (HPA) basado en métricas de CPU o cantidad de peticiones por segundo, con tolerancia a fallos a nivel de zona de disponibilidad (*Availability Zones*).

---

## 9. Guión Paso a Paso para la Defensa en Vivo (Coloquio Grupal / Individual)

Para estructurar la defensa oral y garantizar el cumplimiento de los 100 puntos de la rúbrica, se propone la siguiente secuencia de demostración (duración estimada: 5 minutos):

* **Minuto 0:00 - 1:00 | Presentación de Arquitectura y Acceso en Vivo:**
  * Abrir el navegador en `http://devops-maxivalenzano.com` y mostrar el dominio personalizado con la IP de Azure (`68.211.137.116`).
  * Explicar que la solución se compone de 8 contenedores orquestados: Nginx Gateway, 3 nodos de Frontend, 3 nodos de Backend, Redis persistente y Portainer CE.
* **Minuto 1:00 - 2:00 | Demostración del Tablero Distribuido y Persistencia en Redis:**
  * Crear 3 tareas consecutivas en el Tablero de Tareas.
  * Señalar los badges de color que indican qué nodo backend procesó la escritura (`createdByNode`).
  * Recargar la página (F5) y mostrar cómo el badge superior de lectura cambia de nodo (`servedByNode`), demostrando que todos los nodos comparten el mismo estado centralizado en Redis.
* **Minuto 2:00 - 3:00 | Prueba de Caos y Tolerancia a Fallos (Failover en Vivo):**
  * Abrir la terminal conectada a la VM (o en local) y ejecutar:
    ```bash
    docker compose stop backend-1
    ```
  * Volver inmediatamente a la interfaz web y crear una nueva tarea.
  * Comprobar que el sistema responde de forma instantánea sin errores: Nginx detectó la caída y balanceó la solicitud hacia `backend-2` o `backend-3`.
* **Minuto 3:00 - 4:00 | Demostración del Pipeline CI/CD y DevSecOps:**
  * Proyectar Azure DevOps: mostrar los 4 Stages (`Versioning`, `QualityGate`, `Packaging`, `CD`).
  * Mostrar los resultados de las 42 pruebas unitarias en la pestaña *Tests* y la cobertura de código.
  * Mostrar el dashboard de **SonarQube Cloud** con Quality Gate superado en verde (A en Security Rating, 0 vulnerabilidades).
* **Minuto 4:00 - 5:00 | Panel de Portainer y Conclusión:**
  * Abrir `http://devops-maxivalenzano.com:9000` y mostrar el mapa visual de contenedores, estadísticas de consumo de CPU/RAM de los límites impuestos y los volúmenes persistentes.
  * Presentar la propuesta de arquitectura híbrida PostgreSQL + Redis como visión a futuro.

---

## 10. Conclusiones

La realización del Trabajo Práctico Nº 1 permitió aplicar de manera integral los conceptos teóricos y prácticos fundamentales de la disciplina DevOps. Se transitó desde la contenerización atómica de componentes individuales hasta la orquestación distribuida, la resiliencia ante contingencias operativas y la automatización completa del ciclo de vida del software mediante prácticas modernas de Integración y Entrega Continua (CI/CD) con enfoque de seguridad estática (DevSecOps).

La elección de **Microsoft Azure y Azure DevOps** dotó al proyecto de una madurez técnica y un estándar de ingeniería equiparable al de entornos de producción corporativos, superando con holgura los requerimientos mínimos de la cátedra e implementando mejoras opcionales de alta disponibilidad tanto en el entorno local como en la nube pública.

---

*Trabajo Práctico presentado para su aprobación y defensa oral el 14 de Septiembre de 2026.*  
**Maximiliano Nicolas Valenzano** – Legajo 21664 – UTN FRRe.
