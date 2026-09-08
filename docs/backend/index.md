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
| `POST` | `/api/stress/cpu` | Bucle intensivo de cálculo bloqueante | `{"duration": 3000}` |
| `POST` | `/api/stress/memory` | Retención de buffers en memoria RAM | `{"mb": 50}` |
| `POST` | `/api/stress/memory/clear`| Libera los buffers asignados y llama al Garbage Collector | - |

---

## 💥 Chaos Engineering y Estrés

### 1. Simulación de CPU Bloqueante (`/api/stress/cpu`)
Ejecuta un bucle síncrono intensivo (`Math.Sqrt`) durante el tiempo indicado.
* **Propósito**: Observar la saturación de CPU y la respuesta de Nginx.

```bash
curl -X POST http://localhost:8080/api/stress/cpu \
  -H "Content-Type: application/json" \
  -d '{"duration": 4000}'
```

### 2. Forzar Out-Of-Memory / OOM Killer (`/api/stress/memory`)
Asigna arreglos de `byte[]` en memoria gestionada y los retiene en una lista estática para evitar que el Garbage Collector los recolecte.
* **Propósito**: Superar el límite fijado en el contenedor (128MB) para disparar el OOM Killer del kernel Linux y ver cómo Nginx realiza failover a la otra réplica.

```bash
# Inyectar 60MB adicionales hasta colapsar el contenedor
curl -X POST http://localhost:8080/api/stress/memory \
  -H "Content-Type: application/json" \
  -d '{"mb": 60}'
```

### 3. Prueba de Timeout de Gateway (`/api/delay`)
Simula una demora de procesamiento o un servicio externo colgado.
* Si `ms > 5000` (el `proxy_read_timeout` de Nginx), Nginx cortará la conexión y devolverá `504 Gateway Timeout`.

```bash
curl "http://localhost:8080/api/delay?ms=6000"
```

---

## 🛡️ Límites de Recursos

En el archivo de composición (`compose.yaml` / `compose.prod.yaml`), cada réplica del backend está restringida para simular un entorno de producción acotado:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 128M
```
