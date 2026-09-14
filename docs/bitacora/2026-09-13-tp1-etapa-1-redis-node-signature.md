# 🚀 2026-09-13: TP 1 - Etapa 1: Persistencia en Redis y Tablero Distribuido con Firma de Nodos (.NET 10)

**Fecha**: 2026-09-13  
**Hito**: TP 1 DevOps (UTN FRRe 2026) - Implementación de la **Etapa 1**: incorporación del servicio Redis (`redis:7-alpine`) con volumen persistente, integración del SDK `StackExchange.Redis` en Minimal API .NET 10 y diseño del contrato REST `/api/tasks` con firma de autoría (`createdByNode`) y servicio (`servedByNode`).

---

## 🎯 Objetivos de la sesión

1. **Centralización del Estado (*Stateless Backends*)**: Superar el paradigma de almacenamiento efímero en la memoria de proceso de cada instancia de backend. Almacenar las entidades en un almacén en memoria distribuido (Redis) para posibilitar el escalado horizontal sin pérdida de datos ni necesidad de *sticky sessions*.
2. **Firma de Nodos (*Node Signature Board*)**: Establecer la trazabilidad de qué réplica de backend procesa la creación de tareas y qué réplica atiende las consultas, sentando las bases para la prueba incontrastable de Alta Disponibilidad y tolerancia a fallos ante la cátedra.
3. **Resiliencia de Arranque y Tolerancia a Fallos**: Configurar el cliente de Redis en .NET para que maneje de forma asíncrona y tolerante reconexiones (`AbortOnConnectFail = false`), previniendo caídas del contenedor ante demoras en el arranque de la infraestructura.
4. **Persistencia Duradera**: Configurar el servicio `redis` con un volumen Docker persistente (`redis-data:/data`) para asegurar que la información sobreviva al apagado, recreación o actualización de contenedores.
5. **Compatibilidad hacia atrás**: Mantener intactos los endpoints previos de diagnóstico, ingeniería del caos y estrés (`/info`, `/delay`, `/stress/*`, `/health`).

---

## 💡 1. Arquitectura: "Node Signature Board" sobre Redis

### El Problema de la Memoria Local en Clusters
En una arquitectura con balanceo de carga (como Nginx distribuyendo peticiones en Round-Robin entre múltiples instancias de backend), almacenar datos en colecciones en memoria (`List<T>`, `Dictionary<K,V>`) produce **inconsistencia inmediata**:
- Una tarea creada en `backend-1` no existe para `backend-2` ni `backend-3`.
- Si el usuario refresca la página, los datos parpadean o desaparecen según el nodo que responda.
- Si una instancia falla o es destruida por el orquestador, los datos mueren con el proceso.

```
                      [ Nginx Gateway / Load Balancer ]
                               /      |      \
                              ▼       ▼       ▼
                        [Backend 1] [Backend 2] [Backend 3]
                              │       │       │
                              └───────┼───────┘
                                      ▼
                            [ Almacén Central ]
                                  (REDIS)
                                      │
                                      ▼
                              [ redis-data Vol ]
```

### La Solución: Redis Hash y Doble Firma
Para transformar una lista de tareas convencional en una demostración viva de sistemas distribuidos y DevOps:
1. **Persistencia Compartida**: Todos los nodos leen y escriben sobre la misma base de datos en Redis.
2. **Firma de Creación (`createdByNode`)**: Al recibir un `POST /api/tasks`, el backend estampa el valor de su variable de entorno `INSTANCE_NAME` (ej: `backend-dotnet-1`) en el registro antes de persistirlo en Redis. Esta firma es inmutable.
3. **Firma de Lectura (`servedByNode`)**: Al recibir un `GET /api/tasks`, el backend que atiende la consulta envuelve la lista con su propio nombre de instancia.
4. **Valor Demostrativo**:
   - Si creamos 3 tareas consecutivas, la interfaz mostrará que fueron creadas por distintos nodos (`backend-dotnet-1`, `backend-dotnet-2`, `backend-dotnet-3`), pero todas coexisten en la misma vista.
   - Al refrescar, distintos nodos atienden la lectura sin perder ninguna tarea.
   - Si se simula una caída apagando un nodo (`docker compose stop backend-1`), las tareas creadas por él siguen vivas en Redis y el sistema continúa operando sin degradación visible.

---

## 🛠️ 2. Acciones Realizadas

### 2.1 Gestión de Ramas en Git
Siguiendo la matriz de paralelismo y trabajo con ramas/worktrees definida en `PLAN_TP1.md`:
- Se creó y conmutó la rama de trabajo:
  ```bash
  git checkout -b feature/backend-redis-signature
  ```

### 2.2 Infraestructura como Código (`compose.yaml`)
Se agregaron las siguientes definiciones:
1. **Servicio Redis**:
   ```yaml
   redis:
     image: redis:7-alpine
     container_name: lab-redis
     restart: unless-stopped
     ports:
       - "6379:6379"
     volumes:
       - redis-data:/data
     networks:
       - lab-network
   ```
2. **Enlace en `backend-1`**:
   - `depends_on: [redis]`: Garantiza el orden de levantamiento de dependencias.
   - Variable de entorno `REDIS_CONNECTION=redis:6379`: Indica la cadena de conexión interna en la red puente de Docker.
3. **Volumen Persistente**:
   - Declaración de `redis-data:` en la raíz del archivo Compose.

### 2.3 Dependencias de Backend (`backend/Backend.csproj`)
Se incorporó el driver oficial de alto rendimiento para Redis en .NET:
```xml
<ItemGroup>
  <PackageReference Include="StackExchange.Redis" Version="2.8.24" />
</ItemGroup>
```

### 2.4 Implementación en `backend/Program.cs`

#### Configuración e Inyección de Dependencias
```csharp
var redisConnection = Environment.GetEnvironmentVariable("REDIS_CONNECTION") ?? "localhost:6379";
var redisOptions = ConfigurationOptions.Parse(redisConnection);
redisOptions.AbortOnConnectFail = false;
redisOptions.ConnectTimeout = 5000;
builder.Services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(redisOptions));
```
* **Decisión técnica**: `AbortOnConnectFail = false` es indispensable en arquitecturas de microservicios contenerizados. Permite que el runtime de ASP.NET Core complete su inicialización y escuche en su puerto asignado aún si Redis tarda unos segundos adicionales en aceptar conexiones TCP, reconectando automáticamente en segundo plano.

#### Modelos de Dominio y DTOs
```csharp
public record TaskItem(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("isCompleted")] bool IsCompleted,
    [property: JsonPropertyName("createdByNode")] string CreatedByNode,
    [property: JsonPropertyName("createdAt")] DateTime CreatedAt
);

public record CreateTaskRequest(
    [property: JsonPropertyName("title")] string? Title
);

public record TasksResponse(
    [property: JsonPropertyName("servedByNode")] string ServedByNode,
    [property: JsonPropertyName("totalCount")] int TotalCount,
    [property: JsonPropertyName("tasks")] IEnumerable<TaskItem> Tasks
);
```

#### Endpoints REST Implementados (`/api/tasks`)

| Método | Ruta | Código HTTP | Descripción |
| :--- | :--- | :---: | :--- |
| `GET` | `/api/tasks` | `200 OK` / `503` | Recupera todas las tareas del Hash `"tasks"`, ordenadas cronológicamente por `createdAt` e informando `servedByNode`. |
| `GET` | `/api/tasks/{id}` | `200 OK` / `404` / `503` | Obtiene una tarea puntual por su identificador. |
| `POST` | `/api/tasks` | `201 Created` / `400` / `503` | Valida título, genera UUID, asigna `createdByNode = instanceName` y persiste en Redis. |
| `PUT` | `/api/tasks/{id}/toggle` | `200 OK` / `404` / `503` | Invierte el flag `isCompleted` y actualiza el registro en Redis. |
| `DELETE` | `/api/tasks/{id}` | `204 NoContent` / `404` / `503` | Elimina la tarea del Hash en Redis. |

---

## 🧪 3. Verificación del Contrato de Datos

### Ejemplo de Creación (`POST /api/tasks`)
**Request:**
```bash
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Configurar SAST con CodeQL"}'
```
**Response (`201 Created`):**
```json
{
  "id": "3f628c2e-4cb8-4a92-94b2-03d6d0a79a51",
  "title": "Configurar SAST con CodeQL",
  "isCompleted": false,
  "createdByNode": "backend-dotnet-1",
  "createdAt": "2026-09-13T21:48:10.1234567Z"
}
```

### Ejemplo de Listado (`GET /api/tasks`)
**Request:**
```bash
curl http://localhost:3000/api/tasks
```
**Response (`200 OK`):**
```json
{
  "servedByNode": "backend-dotnet-1",
  "totalCount": 1,
  "tasks": [
    {
      "id": "3f628c2e-4cb8-4a92-94b2-03d6d0a79a51",
      "title": "Configurar SAST con CodeQL",
      "isCompleted": false,
      "createdByNode": "backend-dotnet-1",
      "createdAt": "2026-09-13T21:48:10.1234567Z"
    }
  ]
}
```

---

## 💡 Lecciones Aprendidas & Decisiones de Diseño

1. **Estructura de Datos en Redis (`Hash` vs `Keys` vs `Set`)**:
   - Si guardáramos cada tarea con una clave separada (`task:uuid`), para listar requeriríamos comandos peligrosos como `KEYS task:*` (bloqueante en O(N)) o `SCAN` iterativo complejo.
   - Utilizar un **Redis Hash** con clave `"tasks"` donde cada campo (*field*) es el `id` y el valor es el JSON permite lectura completa con `HGETALL` en una sola operación atómica, y accesos directos $O(1)$ con `HGET`, `HSET` y `HDEL`.
2. **Encapsulamiento en Contenedores (.NET 10 en Host con .NET 8)**:
   - El entorno local del desarrollador cuenta con el SDK de .NET 8.0.403 instalado. Gracias a la estrategia de construcción multi-stage en [backend/Containerfile](file:///c:/Users/m.valenzano/source/repos/dev-ops/backend/Containerfile) utilizando `mcr.microsoft.com/dotnet/sdk:10.0-alpine`, el código compila y se ejecuta en .NET 10 de forma totalmente hermética, demostrando el principio DevOps de **independencia del host**.
3. **Manejo de Estados de Error Semánticos**:
   - En lugar de propagar un fallo `500 Internal Server Error` genérico ante problemas de conexión con la infraestructura de Redis, se intercepta la excepción para devolver `503 Service Unavailable`, informando qué nodo detectó la indisponibilidad de la base de datos.

---

## 📌 Próximos Pasos

- **Etapa 2**: Implementar el Frontend en React 18 ([frontend/src/...](file:///c:/Users/m.valenzano/source/repos/dev-ops/frontend)):
  - Estructura de pestañas en `App.jsx` (Tablero Distribuido vs Laboratorio de Caos y Métricas).
  - Componente `TaskBoard.jsx` con formulario de alta, listado reactivo y badges cromáticos por nodo (`backend-1` en azul, `backend-2` en verde, `backend-3` en naranja).
