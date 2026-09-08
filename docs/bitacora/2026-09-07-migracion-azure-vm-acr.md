# 🚀 2026-09-07: Infraestructura en Azure (VM Linux + ACR) y Estrategia Incremental

**Fecha**: 2026-09-07  
**Hito**: Despliegue de infraestructura IaaS en Azure (VM B2als_v2), configuración de Azure Container Registry (ACR), instalación de Docker Engine nativo y puesta en marcha de la Línea Base.

---

## 🎯 Objetivos de la sesión
- Seleccionar y justificar la arquitectura más formativa para la clase de DevOps (IaaS vs PaaS).
- Crear y aprovisionar la infraestructura base en Azure con la suscripción **Azure for Students**:
  - Máquina Virtual Linux (IaaS).
  - Azure Container Registry (ACR).
  - Reglas de red y firewall (Network Security Group).
- Configurar el entorno de ejecución en la VM con **Docker Engine 29.8** y **Docker Compose v5.5**.
- Estructurar el despliegue con un único archivo de composición (`compose.yaml`) para crecer incrementalmente por etapas con Versionado Semántico 2.0.0.

---

## 🏛️ Ficha Técnica de Servidores y Recursos

| Recurso | Nombre | Tipo / SKU | Región | IP / Endpoint | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Resource Group** | `rg-devops-lab` | Contenedor de Recursos | Chile Central | - | Agrupa toda la infraestructura del lab. |
| **Máquina Virtual** | `vm-dev-ops` | `Standard_B2als_v2`<br>(2 vCPU AMD, 4 GB RAM) | Chile Central | **Public IP**: `68.211.137.116`<br>**Private IP**: `172.16.0.4` | SO: Ubuntu 24.04 LTS.<br>Costo: ~$0.052/hr (cubierto por Students). |
| **Seguridad (NSG)** | `vm-dev-ops-nsg` | Network Security Group | Chile Central | - | Puertos abiertos: **`22` (SSH)** y **`80` (HTTP)**. |
| **Container Registry**| `acrdevopsvalenzano`| Azure Container Registry (Basic)| Chile Central | `acrdevopsvalenzano.azurecr.io` | **User**: `acrdevopsvalenzano`<br>**Pass 1**: `ArwCgwnAjjdVGUBVwUx2WhoUzXae5eoD0IfIBzPoXdsxPIHuoMxMJQQJ99CIAC1KCM3Eqg7NAAACAZCRzhQ7`<br>**Pass 2**: `Fsy0LznEv9EK2hwWtZB0QRZtjsnLkNM71IPfGR1PTK7PJxkiwbnfJQQJ99CIAC1KCM3Eqg7NAAACAZCRsAgX` |
| **Clave SSH** | `vm-dev-ops_key.pem`| RSA 2048 | Local (Windows) | `C:\Users\m.valenzano\Downloads\` | Llave privada de acceso para `azureuser`. |

---

## 🛠️ Comandos Utilizados

### 1. En la Máquina Local (Windows PowerShell)

#### Ajuste de permisos de la clave privada SSH (icacls)
Windows por defecto hereda permisos amplios en `Downloads`, lo que hace que OpenSSH rechace la clave (`Permissions are too open`). Se eliminó la herencia y se restringió al usuario actual:
```powershell
icacls "C:\Users\m.valenzano\Downloads\vm-dev-ops_key.pem" /inheritance:r /grant:r "m.valenzano:(R)"
```

#### Conexión por SSH a la VM
```powershell
ssh -i "C:\Users\m.valenzano\Downloads\vm-dev-ops_key.pem" azureuser@68.211.137.116
```

#### Empaquetado y transferencia del código limpio a la VM
Se comprimió el proyecto excluyendo `node_modules`, `dist`, `bin`, `obj` y `.git`:
```powershell
# 1. Empaquetar código fuente limpio
tar --exclude="node_modules" --exclude="dist" --exclude="bin" --exclude="obj" --exclude=".git" -czf dev-ops.tar.gz backend frontend nginx compose.yaml

# 2. Transferir el archivo a la VM vía SCP
scp -i "C:\Users\m.valenzano\Downloads\vm-dev-ops_key.pem" dev-ops.tar.gz azureuser@68.211.137.116:~/

# 3. Descomprimir en la carpeta ~/dev-ops de la VM
ssh -i "C:\Users\m.valenzano\Downloads\vm-dev-ops_key.pem" azureuser@68.211.137.116 "mkdir -p ~/dev-ops && tar -xzf ~/dev-ops.tar.gz -C ~/dev-ops"
```

### 2. En la Máquina Virtual (Ubuntu 24.04 LTS)

#### Instalación y Configuración del Runtime de Contenedores
```bash
# 1. Actualización e instalación de Docker Engine oficial
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 2. Agregar usuario al grupo docker para evitar usar 'sudo'
sudo usermod -aG docker azureuser
newgrp docker

# 3. Verificación de versiones
docker --version
docker compose version
```

---

## 💡 Decisiones de Arquitectura y Diseño

1. **IaaS (VM Linux) vs PaaS (App Service / Static Web Apps)**:
   - Se eligió la Máquina Virtual porque en DevOps el valor pedagógico está en controlar y ver la red L4/L7, puertos, demonios de sistema (`systemd`), caídas de procesos por kernel (OOM Killer) y balanceo real con Nginx.
   - PaaS abstrae la infraestructura y para habilitar slots de despliegue (Canary/AB) exige tiers como Standard S1 (~$73 USD/mes) que liquidan el crédito de Azure Students.

2. **Elección de Región (`Chile Central` vs `East US`)**:
   - `East US` presentó saturación física (`NotAvailableForSubscription`).
   - Se seleccionó `Chile Central` con la SKU `Standard_B2als_v2` (2 cores AMD EPYC, 4 GB RAM): ofrece latencia mínima (~15-20ms) para Sudamérica por apenas ~$0.05/hora.

3. **Estrategia de Crecimiento Incremental**:
   - **Etapa 1 (Línea Base)**: 1 Frontend + 1 Backend + Nginx Gateway en `compose.yaml`. Sin base de datos ni réplicas.
   - **Etapa 2 (Alta Disponibilidad)**: 2 réplicas del backend con límites de memoria (128M) + failover por OOM.
   - **Etapa 3 (Persistencia & Concurrencia)**: PostgreSQL persistente + endpoints transaccionales para demostrar *race conditions*.
   - **Etapa 4 (Estrategias de Release)**: Canary (90/10), A/B Testing por header y Blue/Green con zero downtime.

4. **Ruteo Unificado por Gateway (Nginx Reverse Proxy)**:
   - El frontend consume el backend de manera agnóstica mediante rutas relativas (`/api/`), delegando la resolución de red y balanceo exclusivamente al Reverse Proxy de Nginx en puerto 80.

#### Autenticación en ACR y Publicación de Imágenes SemVer 2.0.0
```bash
# 1. Login seguro en Azure Container Registry
docker login acrdevopsvalenzano.azurecr.io -u acrdevopsvalenzano -p <PASSWORD>

# 2. Compilación nativa en el servidor con etiquetas SemVer
cd ~/dev-ops
docker build -t acrdevopsvalenzano.azurecr.io/backend:1.0.0 -f ./backend/Containerfile ./backend
docker build -t acrdevopsvalenzano.azurecr.io/frontend:1.0.0 -f ./frontend/Containerfile ./frontend

# 3. Push de los artefactos inmutables al ACR
docker push acrdevopsvalenzano.azurecr.io/backend:1.0.0
docker push acrdevopsvalenzano.azurecr.io/frontend:1.0.0
```

#### Despliegue de la Línea Base Inicial
```bash
# Puesta en marcha con el archivo único de composición
docker compose up -d
```

> **Lección de Arquitectura Nginx**: Al montar la configuración sobre `nginx:alpine`, debe montarse en `/etc/nginx/conf.d/default.conf:ro` en lugar de `/etc/nginx/nginx.conf:ro` para que las directivas `upstream` y `server` se ubiquen dentro del contexto `http` del contenedor sin sobrescribir la configuración raíz.

---

## 🧪 Pruebas y Resultados (Línea Base Validada)

Se verificó la conectividad desde internet hacia la IP pública de la máquina:
```powershell
curl.exe -i http://68.211.137.116/api/info
```
**Respuesta HTTP**:
```http
HTTP/1.1 200 OK
Server: nginx/1.31.5
Content-Type: application/json; charset=utf-8

{"instance":"backend-dotnet-1","hostname":"cbfe09c45597","pid":1,"port":3000,"uptimeSeconds":254,"isHealthy":true}
```
* Navegador: Carga completa de la interfaz en `http://68.211.137.116/`.
* Ruteo: Nginx atiende en puerto 80, sirve estáticos del frontend en `/` y delega las peticiones de datos a `backend-dotnet-1` en `/api/`.

---

## 📌 Próximos Pasos (Alta Disponibilidad)
- [ ] Escalar a 2 réplicas del backend (`backend-1` y `backend-2`) habilitando la segunda réplica en `compose.yaml`.
- [ ] Configurar el balanceo Round-Robin en `nginx/nginx.conf` y verificar la alternancia de respuestas.
- [ ] Ejecutar prueba de saturación de memoria para inducir OOM Killer y validar el failover automático.
