# 🚀 2026-09-12: Despliegue Continuo (CD) en VM Linux con Azure DevOps Environments

**Fecha**: 2026-09-12  
**Hito**: Configuración y resolución de incidentes en el **Despliegue Continuo (CD)** automatizado hacia la Máquina Virtual Linux (`vm-dev-ops`) mediante **Azure Pipelines Environments**, despliegue atómico con Docker Compose y validación post-despliegue (Smoke Testing).

---

## 🎯 Objetivos de la sesión
- Cerrar el ciclo completo de DevOps pasando de la Integración Continua (CI) a la **Entrega y Despliegue Continuo (CD)**.
- Adoptar el modelo de agente nativo de entorno (*Pull-based Agent*) en lugar de exponer puertos SSH o almacenar claves privadas en variables del pipeline.
- Registrar la VM `vm-dev-ops` (Ubuntu 24.04 LTS) como recurso activo dentro del Environment `devops-vm-env`.
- Automatizar la actualización del clúster de microservicios: descarga de imágenes versionadas desde ACR (`acrdevopsvalenzano`), recreación atómica de contenedores (`docker compose up -d`) y verificación de salud de Nginx.

---

## 🏛️ Arquitectura del Despliegue Continuo (Pull-Based Agent)

```
 +-----------------------------------+
 |      AZURE DEVOPS PIPELINES       |
 |                                   |
 |  [Stage 1: SemVer]                |
 |           |                       |
 |  [Stage 2: CI (Push a ACR)]       |
 |           |                       |
 |  [Stage 3: CD (Target: Env)]      |
 +-----------------------------------+
                   |
                   | (Disparo del Job de Despliegue)
                   v
 +---------------------------------------------------------+
 |             ENVIRONMENT: `devops-vm-env`                |
 |                                                         |
 |  +---------------------------------------------------+  |
 |  |   Máquina Virtual Azure (vm-dev-ops / Ubuntu)     |  |
 |  |                                                   |  |
 |  |   [Azure Pipelines Agent (systemd)]               |  |
 |  |      - Servicio: vsts.agent...service             |  |
 |  |      - Comunicación saliente HTTPS (segura)       |  |
 |  |      - Recibe instrucciones del Stage 3           |  |
 |  |                                                   |  |
 |  |   1. Inyecta IMAGE_TAG=$(SEMVER_TAG) en variables |  |
 |  |   2. Fija COMPOSE_PROJECT_NAME="devops-lab"       |  |
 |  |   3. Ejecuta: docker compose pull                 |  |
 |  |   4. Ejecuta: docker compose up -d                |  |
 |  |   5. Smoke Test: curl http://localhost/           |  |
 |  +---------------------------------------------------+  |
 +---------------------------------------------------------+
```

### ¿Por qué este modelo es superior a SSH desde el pipeline?
1. **Seguridad de Red**: No requiere abrir el puerto SSH a los rangos de IPs dinámicas de los agentes de Microsoft en la nube.
2. **Cero Secretos Expuestos**: No se almacena ninguna clave privada RSA (`.pem`) ni contraseña de root en los repositorios o variables de Azure DevOps.
3. **Comunicación Saliente (Outbound HTTPS)**: El agente instalado en la VM consulta a Azure DevOps por el puerto 443; la VM no necesita puertos de gestión expuestos al exterior.
4. **Trazabilidad y Auditoría**: En el panel de Environments queda registrado qué commit, qué versión SemVer y qué usuario aprobó el despliegue en ese servidor exacto.

---

## 🛠️ Acciones Realizadas

1. **Instalación del Agente de Azure Pipelines**:
   - Descarga y extracción de la versión `5.279.0` del agente de Azure Pipelines para Linux x64 en `~/azagent`.
   - Registro en la organización `maxivalenzano` bajo el proyecto `DevOps` y entorno `devops-vm-env`.
   - Configuración como servicio nativo de Linux gestionado por `systemd`: `vsts.agent.maxivalenzano.devops-vm-env.vm-dev-ops.service`.
2. **Actualización de `azure-pipelines.yml`**:
   - Se configuró el Stage de CD para utilizar `environment: { name: $(vmEnvironmentName), resourceType: VirtualMachine }`, garantizando que las tareas se ejecuten directamente en el host productivo.
   - Inyección de variables de entorno dinámicas: `IMAGE_TAG` y `COMPOSE_PROJECT_NAME`.

---

## ⚠️ Dificultades Encontradas y Soluciones Técnicas (Troubleshooting)

### 1. Bucle en la Registración Desatendida del Agente
* **Síntoma**: Al ejecutar el script provisto por la interfaz web de Azure DevOps mediante SSH, el proceso se congeló en bucle leyendo líneas vacías de la terminal.
* **Causa Raíz**: En sesiones SSH no interactivas (sin asignación de pseudo-terminal `pty`), el script de configuración del agente solicitaba la aceptación del acuerdo de licencia (TEE EULA). Al no haber entrada interactiva, la lectura de `stdin` entraba en un ciclo indefinido. Además, el parámetro oficial es sensible a mayúsculas (`--acceptTeeEula`).
* **Solución**: Se cancelaron los procesos huérfanos con `kill -9` y se ejecutó la configuración especificando `--unattended` y `--acceptTeeEula`. El agente se registró en segundos y se activó con `sudo ./svc.sh install azureuser && sudo ./svc.sh start`.

### 2. Colisión de Nombres y Proyectos en Docker Compose: `Conflict: container name "/lab-backend-1" is already in use`
* **Síntoma**: Durante la primera ejecución real del CD, la descarga de imágenes (`pull`) completó exitosamente, pero al ejecutar `docker compose up -d` el paso falló con el error:  
  `service:backend-1:1 Error response from daemon: Conflict. The container name "/lab-backend-1" is already in use by container "e5bd7733cc49..."`.
* **Causa Raíz**: 
  - **Divergencia de Proyecto Compose**: Docker Compose utiliza por defecto el nombre del directorio donde se ejecuta para agrupar los recursos. El agente de Azure DevOps clona el repositorio en `/home/azureuser/azagent/_work/1/s`, por lo que Compose asumió que el proyecto se llamaba `s` (creando la red `s_lab-network`).
  - **Contenedores Huérfanos del Despliegue Manual**: En el host continuaban ejecutándose los contenedores del despliegue inicial realizado 4 días atrás desde la carpeta `~/dev-ops`. Al tener nombres estáticos asignados (`container_name: lab-backend-1`), el nuevo proyecto `s` colisionó con los contenedores existentes.
* **Solución**:
  1. Se detuvieron y eliminaron los contenedores manuales previos (`docker stop lab-nginx lab-frontend lab-backend-1 && docker rm ...`), dejando al pipeline de Azure DevOps como el único orquestador de la infraestructura.
  2. Se fijó explícitamente `export COMPOSE_PROJECT_NAME="devops-lab"` en el script del pipeline para que el namespace de Docker Compose sea determinístico sin importar la ruta donde el agente clone el repositorio.
  3. Se removió la directiva obsoleta `version: '3.8'` del archivo `compose.yaml`.

---

## 🧪 Pruebas y Validación End-to-End

- La corrida subsiguiente calculó el tag SemVer correspondiente.
- El agente en la VM descargó las imágenes recién construidas en ACR (`:2.1.1`).
- Los contenedores se recrearon limpiamente bajo el proyecto `devops-lab`.
- El Smoke Test (`curl -fsS http://localhost/`) validó que el Nginx Gateway responde exitosamente.

---

## 💡 Lecciones Aprendidas

1. **La infraestructura manual debe ceder el control a la automatización**: Dejar contenedores corriendo manualmente genera colisiones de puertos y nombres cuando entra un orquestador de CD. El servidor debe tratarse como ganado (*cattle*), no como mascota (*pet*).
2. **Determinismo en Docker Compose**: Nunca delegar el nombre del proyecto al nombre de la carpeta actual; definir `COMPOSE_PROJECT_NAME` garantiza reproducibilidad en cualquier entorno de ejecución o agente de CI/CD.
