# ⚙️ Microservicio Backend (.NET 10 Minimal API)

El backend es una API REST construida con **.NET 10 LTS Minimal API**, diseñada específicamente para laboratorios de resiliencia, balanceo, monitoreo y concurrencia.

---

## 📌 Tabla de Endpoints

| Método | Endpoint | Descripción | Parámetros / Body |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/` | Ping básico e identidad de instancia | - |
| `GET` | `/api/info` | Métricas de memoria, CPU y uptime | - |
| `GET` | `/api/health` | Liveness de la instancia | - |
| `GET` | `/api/ready` | Readiness contra PostgreSQL y rango de esquema compatible | - |
| `POST` | `/api/health/toggle` | Alterna el estado de salud para pruebas | - |
| `GET` | `/api/tasks` | Lista tareas compartidas | - |
| `GET` | `/api/tasks/{id}` | Consulta una tarea | UUID en ruta |
| `POST` | `/api/tasks` | Crea una tarea | JSON `CreateTaskRequest` |
| `PUT` | `/api/tasks/{id}/toggle` | Cambia el estado completado | UUID en ruta |
| `DELETE` | `/api/tasks/{id}` | Elimina una tarea | UUID en ruta |
| `GET` | `/api/delay` | Respuesta demorada artificialmente | `?ms=3000` |
| `POST` | `/api/stress/cpu` | Bucle intensivo de cálculo | `{"duration": 3000}` |
| `POST` | `/api/stress/memory` | Retiene buffers en memoria | `{"mb": 50}` |
| `POST` | `/api/stress/memory/clear` | Libera buffers de estrés | - |

## Despliegue actual

P1 (`3.1.1-build.87`), P2 (`3.1.2-build.88`) y P3 (`3.1.6-build.91`) se desplegaron sucesivamente y pasaron los cinco stages. P3 está activa con el esquema `20261025000400_004_RequirePriority`; Redis se conserva como legado. Las pruebas manuales de resiliencia, restore off-host y rollback P3→P1→P3 pasaron. Consultá la [bitácora PostgreSQL](../bitacora/2026-10-25-postgresql-ef-migraciones) para resultados y límites de esta evidencia.

## PostgreSQL y migraciones

Las fases P1, P2 y P3 se desplegaron sucesivamente en EC2 con PostgreSQL y EF Core; P3 está activa. Build91 pasó los cinco stages; también pasaron resiliencia y rollback manual P3→P1→P3. Consultá el [plan de integración](./plan-integracion-postgresql-ef), el [guion P1/P2/P3](./migraciones-demo) y la [bitácora](../bitacora/2026-10-25-postgresql-ef-migraciones).

---

## 💥 Chaos Engineering y Estrés

### 1. Simulación de CPU Bloqueante (`/api/stress/cpu`)
Ejecuta un bucle síncrono intensivo (`Math.Sqrt`) durante el tiempo indicado.
* **Propósito**: Observar la saturación de CPU y la respuesta de Nginx.

```bash
curl -X POST http://localhost/api/stress/cpu \
  -H "Content-Type: application/json" \
  -d '{"duration": 4000}'
```

### 2. Prueba de límite de memoria (`/api/stress/memory`)
Asigna arreglos de `byte[]` en memoria gestionada y los retiene en una lista estática para evitar que el Garbage Collector los recolecte.
* **Propósito**: Observar el límite de 128 MB del contenedor. Si se supera, el proceso puede ser terminado y Nginx puede probar otra réplica.

```bash
# Reservar memoria adicional para observar el límite del contenedor
curl -X POST http://localhost/api/stress/memory \
  -H "Content-Type: application/json" \
  -d '{"mb": 60}'
```

### 3. Prueba de Timeout de Gateway (`/api/delay`)
Simula una demora de procesamiento o un servicio externo colgado.
* Si `ms > 5000` (el `proxy_read_timeout` de Nginx), Nginx cortará la conexión y devolverá `504 Gateway Timeout`.

```bash
curl "http://localhost/api/delay?ms=6000"
```

---

## 🛡️ Límites de Recursos

En `compose.yaml`, cada réplica del backend tiene un límite de 0.5 CPU y 128 MB de memoria:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 128M
```
