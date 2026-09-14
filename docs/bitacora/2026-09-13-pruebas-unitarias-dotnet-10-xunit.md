# 🧪 2026-09-13: Pruebas Unitarias Automatizadas con xUnit en .NET 10 (Etapa 4)

**Fecha**: 2026-09-13  
**Hito**: Implementación integral de la suite de pruebas unitarias y de integración para la API del Tablero Distribuido, utilizando **xUnit** en **.NET 10**, aislamiento de persistencia con **Moq** para Redis (`StackExchange.Redis`), validación de contratos JSON y pruebas de endpoints con `WebApplicationFactory`.

---

## 🎯 Objetivos de la sesión
- Cumplir con los requerimientos de la **Etapa 4** del Plan Maestro del TP 1 de DevOps.
- Configurar el SDK oficial de **.NET 10 (10.0.401)** en el entorno de desarrollo y pruebas.
- Crear el proyecto `tests/Backend.Tests` enlazado al microservicio `backend/Backend.csproj`.
- Implementar el modelo de dominio `TaskItem` y la lógica de servicio `ITaskService` garantizando el cumplimiento estricto del contrato acordado para el Tablero Distribuido.
- Diseñar pruebas unitarias exhaustivas para modelos, lógica de negocio con Redis mockeado y endpoints de observabilidad/caos (`/health`).
- Asegurar que `dotnet test` se ejecute al **100% en verde (0 fallas)** desde la raíz de la solución.

---

## 🛠️ Acciones Realizadas y Decisiones de Diseño

### 1. Disponibilización del SDK Oficial de .NET 10
Para compilar y testear de forma nativa contra `net10.0` sin emulaciones:
- Se instaló mediante el gestor de paquetes de Windows (`winget`) el paquete oficial **Microsoft .NET SDK 10.0 (`10.0.401`)**.
- Se verificó la convivencia con SDKs anteriores mediante `dotnet --list-sdks`, validando la disponibilidad de `10.0.401`.

### 2. Modelado de Dominio y Contrato de API (`backend/`)
En concordancia con el contrato establecido en `PLAN_TP1.md` para el Tablero Distribuido:
- **`backend/Models/TaskItem.cs`**:
  - Modelo con invariantes de dominio: el título no puede ser nulo ni contener solo espacios (`ArgumentException`).
  - Identificador único generado por defecto vía `Guid.NewGuid()`.
  - Estampado automático de fecha en UTC (`DateTime.UtcNow`).
  - Estado inicial `isCompleted = false`.
  - Primitiva `Toggle()` para inversión determinista de estado.
  - Atributos `[JsonPropertyName]` para forzar el esquema JSON en camelCase acordado con el Frontend React.
- **`backend/Models/TaskDto.cs`**:
  - `CreateTaskRequest(string? Title)`: Payload tipado para la creación.
  - `TasksResponse(string ServedByNode, int TotalCount, IEnumerable<TaskItem> Tasks)`: Envoltura que estampa el nodo que atiende la consulta de lectura (`servedByNode`).

### 3. Capa de Servicios y Abstracción de Persistencia
Para desacoplar la API de la infraestructura de Redis y facilitar las pruebas:
- **`backend/Services/ITaskService.cs`**:
  - Define `GetAllTasksAsync()`, `CreateTaskAsync(title, nodeName)`, `ToggleTaskAsync(id)` y `DeleteTaskAsync(id)`.
- **`backend/Services/TaskService.cs`**:
  - Implementación sobre **Redis Hash** (`tasks`) utilizando `StackExchange.Redis` (`IDatabase`).
  - Lógica de negocio: serialización JSON de cada tarea, estampado de la firma del nodo (`CreatedByNode`) y ordenamiento cronológico inverso (`CreatedAt DESC`).
  - **Mecanismo de Resiliencia / Fallback**: Si no se inyecta una conexión activa a Redis (por ejemplo, en entornos de desarrollo local sin contenedor levantado), el servicio utiliza un diccionario concurrente en memoria (`ConcurrentDictionary`), permitiendo que el sistema nunca colapse ante la ausencia del broker.
- **Actualización de `Program.cs`**:
  - Registro de `ITaskService` en el contenedor de inyección de dependencias.
  - Implementación de los endpoints `/api/tasks` (GET, POST, PUT toggle, DELETE).
  - Exposición de `public partial class Program { }` para permitir que el arnés de testing monte el servidor en memoria.

### 4. Creación del Proyecto de Pruebas (`tests/Backend.Tests/`)
- Inicialización con `dotnet new xunit -o tests/Backend.Tests`.
- Referencia directa a `backend/Backend.csproj`.
- Incorporación de dependencias de testing:
  - **`Moq` (4.20.72)**: Para simular el comportamiento de `IDatabase` de StackExchange.Redis sin requerir un servidor Redis real.
  - **`Microsoft.AspNetCore.Mvc.Testing` (10.0.12)**: Para pruebas de integración de endpoints Minimal API en memoria (TestHost).
- Unificación en la solución raíz moderna **`devops.slnx`** (`.NET 10 Solution Format`), integrando `backend` y `tests`.

---

## 🔬 Cobertura y Detalle de las Pruebas

Se diseñaron **4 suites de pruebas** cubriendo 21 casos de test automatizados:

### 1. `TaskItemTests.cs` (Modelo e Invariantes)
- `Constructor_Default_InitializesWithDefaultValues`: Comprueba que una tarea instanciada sin parámetros inicialice un UUID válido, estado incompleto y timestamp UTC actual.
- `Constructor_WithValidArguments_SetsPropertiesProperly`: Verifica que los argumentos de título y nodo se asignen correctamente.
- `Constructor_WithInvalidTitle_ThrowsArgumentException`: Evalúa mediante `[Theory]` con valores `null`, `""` y `"   "` que se lancen excepciones con el nombre de parámetro `title`.
- `Toggle_WhenCalledMultipleTimes_InvertsIsCompletedState`: Verifica la alternancia de estados `false -> true -> false`.
- `TaskItem_JsonSerialization_MatchesAgreedContract`: Valida contra el contrato estricto de JSON (`id`, `title`, `isCompleted`, `createdByNode`, `createdAt`).
- `TaskItem_JsonDeserialization_PreservesState`: Valida que la deserialización reconstruya fielmente el objeto en memoria.

### 2. `TaskServiceTests.cs` (Lógica de Negocio y Mocks de Redis)
- `CreateTaskAsync_WithValidInput_PersistsToRedisAndReturnsTask`: Verifica que el servicio estampe la firma del nodo, guarde la tarea serializada en el Hash `tasks` de Redis mediante `mockDb.Verify(..., Times.Once)` y la retorne.
- `CreateTaskAsync_WithInvalidTitle_ThrowsArgumentException`: Comprueba que títulos vacíos sean rechazados antes de consultar a Redis.
- `GetAllTasksAsync_ReturnsAllStoredTasksOrderedByCreatedAtDescending`: Simula entradas en Redis Hash y verifica que el servicio devuelva la colección ordenada por fecha descendente.
- `ToggleTaskAsync_WhenTaskExists_InvertsCompletionAndUpdatesRedis`: Verifica lectura, toggle y sobreescritura atómica en Redis.
- `ToggleTaskAsync_WhenTaskDoesNotExist_ReturnsNull`: Comprueba el manejo de claves inexistentes sin invocar escrituras.
- `DeleteTaskAsync_WhenTaskExists_ReturnsTrue`: Verifica la eliminación en Redis (`HashDeleteAsync`).
- `DeleteTaskAsync_WhenTaskDoesNotExist_ReturnsFalse`: Valida el retorno booleano cuando la clave no existe.
- `InMemoryFallback_OperatesSeamlesslyWhenRedisNotConnected`: Comprueba que la estrategia fallback en memoria permita crear, listar, togglear y eliminar tareas de manera autónoma.

### 3. `HealthEndpointTests.cs` (Observabilidad y Tolerancia a Fallos)
- `HealthEndpoint_LifecycleAndToggle_ReturnsExpectedStatusCodesAndPayloads`:
  1. `GET /health` responde `200 OK` con `status: "UP"`.
  2. `POST /api/health/toggle` conmuta el estado del backend a degradado.
  3. `GET /health` responde `500 InternalServerError` con `status: "DOWN"`.
  4. Segundo toggle restaura el servicio a `200 OK` y `status: "UP"`.
- `RootEndpoint_ReturnsOnlineStatus`: Valida que la raíz `/` responda `200 OK` indicando que el servicio está en línea.

### 4. `TaskEndpointTests.cs` (Integración de Endpoints REST)
- `TaskEndpoints_FullCrudFlow_SucceedsAccordingToContract`:
  1. `POST /api/tasks` con título vacío retorna `400 Bad Request`.
  2. `POST /api/tasks` con título válido retorna `201 Created` con la tarea creada.
  3. `GET /api/tasks` retorna `200 OK` con la envoltura `TasksResponse` conteniendo `servedByNode` y la lista de tareas.
  4. `PUT /api/tasks/{id}/toggle` retorna `200 OK` con `isCompleted: true`.
  5. `DELETE /api/tasks/{id}` elimina la tarea con `200 OK`.
  6. `PUT /api/tasks/{id}/toggle` posterior retorna `404 Not Found`.

---

## 🧪 Pruebas y Resultados de Ejecución

Comando ejecutado desde la raíz del repositorio:
```powershell
dotnet test
```

### Salida de Ejecución:
```text
  Determining projects to restore...
  All projects are up-to-date for restore.
  Backend -> ...\backend\bin\Debug\net10.0\Backend.dll
  Backend.Tests -> ...\tests\Backend.Tests\bin\Debug\net10.0\Backend.Tests.dll
Test run for ...\tests\Backend.Tests\bin\Debug\net10.0\Backend.Tests.dll (.NETCoreApp,Version=v10.0)
A total of 1 test files matched the specified pattern.

Passed!  - Failed:     0, Passed:    21, Skipped:     0, Total:    21, Duration: 733 ms - Backend.Tests.dll (net10.0)
```

| Métrica | Valor |
| :--- | :--- |
| **Framework de Pruebas** | xUnit 2.9.3 + VSTest Adapter 3.1.4 |
| **Runtime Target** | .NET 10.0 (net10.0) |
| **Total de Pruebas** | 21 |
| **Pruebas Exitosas** | 21 (100%) |
| **Fallas / Errores** | 0 |
| **Tiempo de Ejecución** | 733 ms |

---

## 💡 Decisiones de Arquitectura y DevOps

1. **Aislamiento de Tests (Fast Feedback Loop)**:
   - Las pruebas unitarias no deben requerir un contenedor de Redis en ejecución para validar la lógica. Mediante `Moq`, se simulan las llamadas a `IDatabase`, logrando una ejecución en menos de un segundo (733 ms) que puede correr localmente o en cualquier runner de CI sin dependencias externas.
2. **Pruebas de Integración con `WebApplicationFactory`**:
   - En lugar de limitarse a probar clases aisladas, se probó la canalización HTTP completa (routing, serialización System.Text.Json, inyección de dependencias, códigos de estado HTTP) levantando la aplicación en memoria de forma ligera.
3. **Formato de Solución `.slnx`**:
   - Se adoptó el formato XML limpio introducido en las versiones recientes de .NET (`devops.slnx`), reduciendo la sobrecarga de identificadores GUID del formato tradicional `.sln` y facilitando la resolución de conflictos en Git.

---

## 📌 Próximos Pasos
- [ ] **Etapa 5**: Incorporar la ejecución de `dotnet test --logger "trx"` en el pipeline de GitHub Actions / Azure Pipelines.
- [ ] **Etapa 5**: Configurar el análisis estático de seguridad (SAST) con CodeQL.
- [ ] Integrar con las ramas paralelas de **Etapa 1** (Redis en compose) y **Etapa 2** (Frontend Board UI).
