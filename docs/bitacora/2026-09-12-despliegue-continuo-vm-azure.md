# 🚀 2026-09-12: Despliegue Continuo (CD) en VM Linux con Azure DevOps Environments

**Fecha**: 2026-09-12  
**Hito**: Configuración de Despliegue Continuo (CD) automatizado hacia la Máquina Virtual Linux (`vm-dev-ops`) mediante **Azure Pipelines Environments**, despliegue atómico con Docker Compose y validación post-despliegue (Smoke Testing).

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
 |  |   [Azure Pipelines Agent (Service)]               |  |
 |  |      - Comunicación saliente HTTPS (segura)       |  |
 |  |      - Recibe instrucciones del Stage 3           |  |
 |  |                                                   |  |
 |  |   1. Inyecta IMAGE_TAG=$(SEMVER_TAG) en .env      |  |
 |  |   2. Ejecuta: docker compose pull                 |  |
 |  |   3. Ejecuta: docker compose up -d                |  |
 |  |   4. Smoke Test: curl http://localhost/           |  |
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

1. [En curso] Generación del script de registro del agente de Azure DevOps para Linux.
2. [En curso] Ejecución del script en `vm-dev-ops` e instalación como servicio del sistema (`systemd`).
3. [En curso] Actualización de `azure-pipelines.yml` para ejecutar las tareas de despliegue sobre el recurso `VirtualMachine`.

---

## 📌 Próximos Pasos
- Obtener el comando de registro desde el portal de Azure DevOps en el ambiente `devops-vm-env`.
- Correr el script en la VM y verificar que figure en estado **Online**.
- Disparar el pipeline completo y verificar el despliegue en vivo en `http://68.211.137.116`.
