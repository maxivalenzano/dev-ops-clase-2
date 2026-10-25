# ⚙️ Microservicio Backend (.NET 10 Minimal API)

El backend es una API REST construida con **.NET 10 LTS Minimal API**, diseñada específicamente para laboratorios de resiliencia, balanceo, monitoreo y concurrencia.

---

## 📌 Tabla de Endpoints

| Método | Endpoint | Descripción | Parámetros / Body |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/` | Ping básico y estado de la instancia | - |
| `GET` | `/api/info` | Métricas de memoria (Working Set RSS, Heap), CPU, uptime | - |
| `GET` | `/api/health` | Health check (`200 UP` o `500 DOWN`) | - |
| `POST` | `/api/health/toggle` | Alterna el estado de salud de la instancia | - |
| `GET` | `/api/delay` | Respuesta demorada artificialmente | `?ms=3000` |

## Despliegue actual

La versión `3.0.0-build.81` está desplegada en [http://18.216.227.211](http://18.216.227.211), con tres réplicas backend y Redis interno en EC2. Las validaciones confirmaron lectura/escritura compartida en Redis, persistencia de una tarea tras rollback, nueva entrega y reinicio real de Ubuntu, además de 30 solicitudes atendidas entre las tres réplicas. La tarea marcador se eliminó después de la prueba y Redis quedó vacío.
| `POST` | `/api/stress/cpu` | Bucle intensivo de cálculo bloqueante | `{"duration": 3000}` |
| `POST` | `/api/stress/memory` | Retención de buffers en memoria RAM | `{"mb": 50}` |
| `POST` | `/api/stress/memory/clear`| Libera los buffers asignados y llama al Garbage Collector | - |

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
