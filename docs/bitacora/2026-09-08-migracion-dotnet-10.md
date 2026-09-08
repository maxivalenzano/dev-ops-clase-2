# 🚀 2026-09-08: Migración a .NET 10 (LTS) y Contenedorización Inmutable

**Fecha**: 2026-09-08  
**Hito**: Actualización del microservicio backend a **.NET 10 (LTS)**, preservando el diseño *single-file* (Minimal API), aislando el SDK en un contenedor multi-stage Alpine y versionando la imagen como SemVer `2.0.0`.

---

## 🎯 Objetivos de la sesión
- Evaluar el ciclo de soporte de Microsoft y seleccionar la versión de .NET adecuada para el laboratorio pedagógico.
- Migrar el proyecto backend a **.NET 10 LTS** preservando el enfoque *single-file* en `Program.cs`.
- Actualizar el `Containerfile` con imágenes oficiales Alpine de Microsoft Container Registry (MCR).
- Respetar el principio de **infraestructura inmutable**: no contaminar el sistema operativo host (Ubuntu 24.04 LTS) con runtimes o SDKs manuales.
- Actualizar `compose.yaml` bajo Versionado Semántico (`2.0.0`).

---

## 🛠️ Acciones Realizadas

### 1. Actualización de `Backend.csproj`
Se modificó el Target Framework Moniker (TFM) a `net10.0`:
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RootNamespace>Backend</RootNamespace>
  </PropertyGroup>

</Project>
```

### 2. Preservación Estricta de Single-File y Optimizaciones (.NET 10)
Se mantuvo el archivo `Program.cs` en un único archivo autocontenido, incorporando mejoras idiomáticas del runtime:
- **`System.Threading.Lock`**: Se reemplazó el monitor genérico `new object()` por la nueva primitiva nativa `Lock bufferLock = new();` de C# 13 / .NET 9+, optimizando la sincronización de buffers en memoria.
- **`Random.Shared`**: Se eliminó la instanciación repetida de `new Random()` por request en `/api/stress/cpu`, evitando alocaciones innecesarias en el Heap.
- **`app.MapGroup("/api")`**: Enrutamiento unificado bajo grupo semántico manteniendo todas las rutas existentes.
- **Endpoints de infraestructura y caos**: `/`, `/health`, `/api/info`, `/api/delay`, `/api/stress/*`, `/api/health/toggle`.
- **DTOs al pie**: Records al final del archivo (`CpuStressRequest`, `MemoryStressRequest`).

Sin controladores tradicionales (`Controllers/`), sin archivos de configuración dispersos ni interfaces innecesarias.

### 3. Actualización de `Containerfile` (Multi-stage Build)
Se actualizaron las imágenes base de Alpine en MCR a la versión `10.0-alpine`:
```dockerfile
# Multi-stage .NET 10 Containerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY Backend.csproj ./
RUN dotnet restore Backend.csproj

# Copy source code and build/publish
COPY Program.cs ./
RUN dotnet publish Backend.csproj -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runner
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production
ENV PORT=3000

EXPOSE 3000

USER app

ENTRYPOINT ["dotnet", "Backend.dll"]
```

### 4. Actualización de `compose.yaml`
Se actualizó la etiqueta de imagen del backend a `2.0.0`:
```yaml
  # 3. Backend Instance 1 (.NET 10 Minimal API)
  backend-1:
    build:
      context: ./backend
      dockerfile: Containerfile
    image: ${ACR_LOGIN_SERVER:-acrdevopsvalenzano.azurecr.io}/backend:2.0.0
    container_name: lab-backend-1
```

---

## 💡 Decisiones de Arquitectura y DevOps

### 1. ¿Por qué .NET 10 (LTS) y no .NET 11?
- **Ciclo de vida y disponibilidad**: Microsoft publica nuevas versiones mayores en noviembre de cada año:
  - Los años pares (.NET 6, .NET 8, .NET 10) corresponden a versiones **LTS** (Long Term Support, 3 años de soporte).
  - Los años impares (.NET 7, .NET 9, .NET 11) son **STS** (Standard Term Support, 2 años de soporte).
- .NET 11 tiene fecha de lanzamiento oficial prevista para noviembre de 2026. Al momento de esta sesión, no se encuentra disponible como versión GA en los repositorios de paquetes ni en los feeds oficiales de producción.
- Optar por **.NET 10 LTS** garantiza un runtime de soporte extendido, altamente estable y con imágenes Alpine oficiales disponibles en MCR.

### 2. El Host Inmutable: No Instalar SDKs en Ubuntu 24.04
- **Anti-patrón detectado**: Instalar el SDK en el servidor vía `apt install` o scripts manuales ensucia el sistema operativo, genera colisiones de versiones y rompe el principio de reproducibilidad.
- **Práctica DevOps**: La máquina virtual solo aloja **Docker Engine**. Toda la cadena de compilación (`dotnet restore`, `dotnet publish`) y el entorno de ejecución se ejecutan dentro del contenedor multi-stage. Esto permite que el entorno sea idéntico en desarrollo local, CI/CD y producción en Azure.

### 3. Filosofía Single-File Minimal API
- En microservicios de laboratorio y utilitarios, la simplicidad y la legibilidad son prioritarias (*Concepts > Code*). 
- Mantener la aplicación en un solo archivo evita la sobreingeniería arquitectónica, permitiendo que un desarrollador o estudiante entienda el flujo completo de la API en una sola lectura sin saltar entre decenas de archivos.

### 4. Versionado Semántico (SemVer 2.0.0)
- El paso de .NET 8 a .NET 10 representa un cambio de versión mayor de la plataforma de ejecución. 
- En apego a SemVer (`MAJOR.MINOR.PATCH`), se incrementó la etiqueta del artefacto inmutable a `2.0.0` en Azure Container Registry (`acrdevopsvalenzano.azurecr.io/backend:2.0.0`).

---

## 🧪 Comandos para Construcción, Publicación y Despliegue

### 1. Construcción local o remota de la nueva imagen
```bash
docker build -t acrdevopsvalenzano.azurecr.io/backend:2.0.0 -f ./backend/Containerfile ./backend
```

### 2. Publicación de la imagen en ACR
```bash
docker push acrdevopsvalenzano.azurecr.io/backend:2.0.0
```

### 3. Actualización de servicios con Docker Compose
```bash
docker compose up -d --no-deps --build backend-1
```

### 4. Verificación del runtime en `/api/info`
```bash
curl -s http://localhost/api/info | grep platform
```

---

## 📌 Próximos Pasos
- [ ] Construir la imagen `backend:2.0.0` en la VM de Azure o localmente con Podman / Docker.
- [ ] Realizar push a `acrdevopsvalenzano.azurecr.io`.
- [ ] Continuar con la Etapa 2 de la bitácora anterior: habilitar la réplica `backend-2` y balanceo en Nginx.
