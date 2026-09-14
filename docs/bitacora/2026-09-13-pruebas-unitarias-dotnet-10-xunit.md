# 🧪 2026-09-13: TP 1 - Etapa 4: Pruebas Unitarias Backend (.NET 10 con xUnit)

**Fecha**: 2026-09-13  
**Hito**: TP 1 DevOps (UTN FRRe 2026) - Implementación de la **Etapa 4**: creación del proyecto de pruebas automatizadas `tests/Backend.Tests` en .NET 10 utilizando xUnit, Moq y Microsoft.AspNetCore.Mvc.Testing. Cobertura completa de modelos de dominio, capa de servicios con persistencia en Redis (aislado mediante mocks) y endpoints HTTP REST, integrando la ejecución y reporte de resultados en Azure Pipelines con fallo bloqueante si los tests no están 100% en verde.

---

## 🎯 Objetivos de la sesión

1. **Aislamiento y Calidad de Código**: Separar el dominio y lógica de negocio del backend en modelos estructurados (`TaskItem`, `CreateTaskRequest`, `TasksResponse`) y servicio (`ITaskService`, `TaskService`), desacoplando la dependencia directa de Redis mediante interfaces.
2. **Suite de Pruebas Automatizadas en .NET 10**: Inicializar el proyecto `tests/Backend.Tests/Backend.Tests.csproj` e implementar pruebas unitarias y de integración para validar reglas de negocio, validaciones y contratos JSON.
3. **Mocks de Infraestructura Externa**: Utilizar la biblioteca `Moq` para simular las llamadas a `IDatabase` (`StackExchange.Redis`), garantizando pruebas unitarias deterministas, rápidas y que no dependan de una instancia de Redis en ejecución.
4. **Pruebas de Integración Web con WebApplicationFactory**: Probar el comportamiento real de los endpoints HTTP (`/health`, `/api/health/toggle`, `/api/tasks`) levantando un servidor de prueba en memoria sin requerir puertos físicos.
5. **Quality Gate Estricto en CI**: Incorporar las tareas `dotnet test` y `PublishTestResults@2` con `failTaskOnFailedTests: true` en el Stage 2 (CI) de `azure-pipelines.yml`, impidiendo la compilación y publicación de imágenes OCI si alguna prueba falla.

---

## 🧩 1. Arquitectura de Pruebas y Diseño

### Desacoplamiento de la Capa de Datos

Para posibilitar pruebas unitarias limpias sin requerir un servidor Redis real levantado durante la ejecución de los tests o en el runner de CI, se estructuró la aplicación en capas:

```text
                        ┌───────────────────────────────┐
                        │   Program.cs (Minimal API)    │
                        └───────────────┬───────────────┘
                                        │ (Inyección de Dependencias)
                                        ▼
                        ┌───────────────────────────────┐
                        │         ITaskService          │
                        └───────────────┬───────────────┘
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 ▼                                             ▼
  ┌─────────────────────────────┐               ┌─────────────────────────────┐
  │         TaskService         │               │     Mock<IDatabase> /       │
  │ (Producción: Redis + Memory)│               │  ConcurrentDictionary (Test)│
  └─────────────────────────────┘               └─────────────────────────────┘
```

### Componentes de la Suite de Pruebas

| Archivo de Prueba | Tipo de Prueba | Tecnologías | Responsabilidad Principal |
| :--- | :--- | :--- | :--- |
| `TaskItemTests.cs` | Unitaria (Dominio) | xUnit | Validar constructores, GUIDs por defecto, timestamp UTC, rechazo de títulos vacíos/nulos (`ArgumentException`), toggle y serialización JSON. |
| `TaskServiceTests.cs` | Unitaria (Lógica/Mock) | xUnit + Moq | Verificar interacción con Redis (`HashSetAsync`, `HashGetAllAsync`, `HashDeleteAsync`), ordenamiento temporal y modo fallback en memoria. |
| `HealthEndpointTests.cs` | Integración HTTP | `WebApplicationFactory<Program>` | Validar ciclo de vida de salud: `200 UP`, toggle manual a `500 DOWN`, recuperación a `200 UP` y endpoints `/` y `/api/info`. |
| `TaskEndpointTests.cs` | Integración API REST | `WebApplicationFactory<Program>` | Validar el contrato HTTP completo de `/api/tasks`: validación 400 Bad Request, creación 201 Created, lectura 200 OK, toggle 200 OK y eliminación 204 No Content. |
| `ChaosEndpointTests.cs` | Integración HTTP (Resiliencia) | `WebApplicationFactory<Program>` | Validar endpoints de laboratorio de caos: `/api/delay`, cómputo acotado en `/api/stress/cpu` y asignación/liberación (`/stress/memory/clear`). |

---

## 🛠️ 2. Detalle de Implementación

### 2.1 Proyecto de Tests (`tests/Backend.Tests/Backend.Tests.csproj`)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="coverlet.collector" Version="6.0.4" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.12" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="Moq" Version="4.20.72" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="3.1.4" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\backend\Backend.csproj" />
  </ItemGroup>
</Project>
```

### 2.2 Validación de Contrato JSON en `TaskItemTests.cs`

Se asegura que el modelo cumpla estrictamente con el contrato pactado en `PLAN_TP1.md` tanto al serializar como al deserializar:

```csharp
[Fact]
public void TaskItem_JsonSerialization_MatchesAgreedContract()
{
    var task = new TaskItem("task-fixed-uuid-1234", "Contrato de Tarea", true, "backend-dotnet-2", new DateTime(2026, 9, 13, 21, 15, 0, DateTimeKind.Utc));

    var json = JsonSerializer.Serialize(task);
    using var doc = JsonDocument.Parse(json);
    var root = doc.RootElement;

    Assert.Equal("task-fixed-uuid-1234", root.GetProperty("id").GetString());
    Assert.Equal("Contrato de Tarea", root.GetProperty("title").GetString());
    Assert.True(root.GetProperty("isCompleted").GetBoolean());
    Assert.Equal("backend-dotnet-2", root.GetProperty("createdByNode").GetString());
    Assert.Equal("2026-09-13T21:15:00Z", root.GetProperty("createdAt").GetString());
}
```

### 2.3 Simulación de Redis con `Moq` en `TaskServiceTests.cs`

Las operaciones contra Redis se testean verificando que los métodos de `IDatabase` sean invocados con los argumentos exactos y que las excepciones de conexión provoquen una degradación agraciada (*graceful degradation*) hacia el almacén en memoria:

```csharp
[Fact]
public async Task CreateTaskAsync_WithValidInput_PersistsToRedisAndReturnsTask()
{
    var mockDb = new Mock<IDatabase>();
    var service = new TaskService(mockDb.Object);
    var title = "Configurar SAST con CodeQL";
    var nodeName = "backend-dotnet-1";

    mockDb.Setup(d => d.HashSetAsync(
        "tasks",
        It.IsAny<RedisValue>(),
        It.IsAny<RedisValue>(),
        When.Always,
        CommandFlags.None
    )).ReturnsAsync(true);

    var result = await service.CreateTaskAsync(title, nodeName);

    Assert.NotNull(result);
    Assert.Equal(title, result.Title);
    Assert.Equal(nodeName, result.CreatedByNode);
    Assert.False(result.IsCompleted);

    mockDb.Verify(d => d.HashSetAsync(
        "tasks",
        result.Id,
        It.Is<RedisValue>(v => v.ToString().Contains(title)),
        When.Always,
        CommandFlags.None
    ), Times.Once);
}
```

---

## 🛡️ 3. Integración en Azure Pipelines (Quality Gate)

En `azure-pipelines.yml`, se incorporó la ejecución de las pruebas, la recolección de cobertura multiplataforma y la publicación de resultados en el formato estándar VSTest (`.trx`) y Cobertura XML:

```yaml
          # 1. Validación de compilación de Backend
          - bash: |
              echo "==> Verificando compilación de Backend .NET 10..."
              dotnet build backend/Backend.csproj -c Release
            displayName: 'Validar Backend (.NET 10)'

          # 2. Ejecución de Pruebas Unitarias (.NET 10)
          - bash: |
              echo "==> Ejecutando Pruebas Unitarias en .NET 10..."
              dotnet test tests/Backend.Tests/Backend.Tests.csproj \
                --configuration Release \
                --logger "trx;LogFileName=test_results.trx" \
                --collect:"XPlat Code Coverage"
            displayName: 'Ejecutar Tests Unitarios (.NET 10)'

          - task: PublishTestResults@2
            displayName: 'Publicar Resultados de Tests'
            inputs:
              testResultsFormat: 'VSTest'
              testResultsFiles: '**/test_results.trx'
              failTaskOnFailedTests: true
            condition: succeededOrFailed()

          - task: PublishCodeCoverageResults@2
            displayName: 'Publicar Cobertura de Código'
            inputs:
              summaryFileLocation: '**/coverage.cobertura.xml'
            condition: succeededOrFailed()
```

---

## 📊 4. Verificación y Resultados

### Ejecución Local

Comando ejecutado en la terminal:
```bash
dotnet test tests/Backend.Tests/Backend.Tests.csproj --configuration Release --logger "trx;LogFileName=test_results.trx" --collect:"XPlat Code Coverage"
```

Salida obtenida:
```text
Test run for .../Backend.Tests.dll (.NETCoreApp,Version=v10.0)
A total of 1 test files matched the specified pattern.
Results File: .../tests/Backend.Tests/TestResults/test_results.trx
Attachments: .../coverage.cobertura.xml

Passed!  - Failed:     0, Passed:    42, Skipped:     0, Total:    42, Duration: 1 s - Backend.Tests.dll (net10.0)
```

**Métricas de Calidad Alcanzadas**:
- **Pruebas ejecutadas**: 42 pruebas ejecutadas, 42 en verde (100% de éxito), 0 fallidas, 0 omitidas.
- **Cobertura de Líneas (`line-rate`)**: **87.29%** (426 / 488 líneas).
- **Cobertura de Ramas (`branch-rate`)**: **88.46%** (69 / 78 ramas).
- **Publicación en CI**: Publicación dual de VSTest (`.trx`) y Cobertura (`coverage.cobertura.xml`) con detención automática del pipeline ante fallos.
