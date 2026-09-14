# 🚀 2026-09-13: Implementación Etapa 2 - Tablero Distribuido (TaskBoard) con Firmas de Nodo sobre Redis

**Fecha**: 2026-09-13  
**Hito**: Desarrollo integral del componente React 18 `TaskBoard` en worktree aislado, visualización de firmas de nodo (`createdByNode` y `servedByNode`), navegación por pestañas para convivencia con el panel de caos y métricas existente (`ChaosLab`), y validación de compilación con Vite.

---

## 🎯 Objetivos de la sesión
- Ejecutar de forma aislada y no bloqueante la **Etapa 2** del Plan Maestro (`PLAN_TP1.md`) utilizando Git Worktrees (`distributed_task_board`).
- Implementar el componente interactivo `TaskBoard.jsx` consumiendo el contrato REST convenido (`/api/tasks`):
  - `GET /api/tasks`: recuperación de tareas y firma del nodo lector (`servedByNode`).
  - `POST /api/tasks`: creación de tareas persistidas en Redis con firma de origen (`createdByNode`).
  - `PUT /api/tasks/{id}/toggle`: alternado de estado completado con actualización optimista.
  - `DELETE /api/tasks/{id}`: eliminación física de la clave/registro en Redis.
- Diseñar la señalización visual de firmas de arquitectura distribuida:
  - **Firma de Lectura (`servedByNode`)**: Badge dinámico destacado en el encabezado indicando qué nodo atendió el último `GET`.
  - **Firma de Creación (`createdByNode`)**: Badge coloreado por tarea según el contenedor que atendió el `POST`.
- Reorganizar la interfaz principal (`App.jsx`) con un sistema de navegación por pestañas (`tabs-nav`) para que convivan el **Tablero Distribuido** y el **Laboratorio de Caos y Métricas**.
- Modularizar el dashboard de caos en `ChaosLab.jsx` para garantizar alta cohesión y mantenibilidad.
- Validar la compilación de producción con Vite (`npm run build`).

---

## 🛠️ Acciones Realizadas y Arquitectura de Componentes

### 1. Componente del Tablero Distribuido (`TaskBoard.jsx`)
Se creó el componente en `frontend/src/components/TaskBoard.jsx` implementando:
* **Firma de Nodo Lector (`servedByNode`)**:
  - En la parte superior se dispuso una tarjeta de estado con el indicador `"Última lectura atendida por: [Badge Nodo]"`.
  - Este badge refleja la instancia balanceada por Nginx en cada petición `GET /api/tasks` y cuenta con un botón de recarga manual para evidenciar el balanceo round-robin.
* **Firma de Nodo Creador (`createdByNode`) y Asignación de Paleta**:
  - Se implementó la función auxiliar `getNodeStyle(nodeName)` que mapea los nombres de nodo a colores corporativos consistentes:
    - `backend-dotnet-1` (o conteniendo `1`): Azul (`--accent-blue`).
    - `backend-dotnet-2` (o conteniendo `2`): Verde (`--accent-green`).
    - `backend-dotnet-3` (o conteniendo `3`): Ámbar/Naranja (`--accent-amber`).
    - Fallback / Otros: Violeta (`--accent-purple`).
  - Cada tarjeta de tarea incluye el badge de su nodo creador inmutable, fecha y hora local formateada, checkbox personalizado y botón de borrado (`🗑️`).
* **Filtros y Métricas en Memoria**:
  - Contadores en tiempo real de tareas totales en Redis, pendientes y completadas.
  - Pestañas de filtrado rápido: *Todas*, *Pendientes* y *Completadas*.
* **Resiliencia ante Backend en Desarrollo**:
  - Si el backend de la Etapa 1 aún no está levantado o Redis se encuentra inaccesible, el componente captura el error de red de forma no bloqueante, presentando una alerta amigable con botón de reintento.

### 2. Modularización del Laboratorio de Caos (`ChaosLab.jsx`)
Para evitar sobrecargar `App.jsx`, se extrajo la interfaz preexistente del laboratorio a `frontend/src/components/ChaosLab.jsx`:
- Conservación íntegra de la barra de métricas (Total Requests, Success 2xx, Errors, Latencia media).
- Conservación del gráfico de distribución upstream de Nginx y tarjeta de información del host activo.
- Generador de carga concurrente configurable (peticiones y concurrencia).
- Controles de caos: inyección de retardo (para provocar timeouts 504), consumo forzado de CPU, fuga de RAM (OOM Kill) y alternado de estado `/health` (UP/DOWN).
- Terminal interactiva de streaming de eventos y respuestas HTTP.

### 3. Navegación por Pestañas en `App.jsx`
Se reestructuró `frontend/src/App.jsx` incorporando un selector moderno de pestañas:
```jsx
<nav className="tabs-nav">
  <button
    className={`tab-button ${activeTab === 'board' ? 'active' : ''}`}
    onClick={() => setActiveTab('board')}
  >
    <span>📋</span> Tablero Distribuido
  </button>
  <button
    className={`tab-button ${activeTab === 'chaos' ? 'active' : ''}`}
    onClick={() => setActiveTab('chaos')}
  >
    <span>⚡</span> Laboratorio de Caos y Métricas
  </button>
</nav>
```
- La pestaña predeterminada al cargar la aplicación es el **Tablero Distribuido**.
- Los eventos disparados desde el tablero (creación, toggle y borrado de tareas) se envían al log central mediante la prop `onLogEvent`, permitiendo ver el rastro completo en la consola de eventos al cambiar a la pestaña de caos.

### 4. Estilos y Micro-interacciones (`index.css`)
Se añadieron reglas CSS manteniendo la estética *Dark Mode* (`#0f172a`, `#1e293b`) del laboratorio:
- Selector de pestañas con bordes suaves, iluminación activa y transiciones suaves.
- Checkbox accesible con marca de verificación SVG/CSS.
- Tarjetas de tareas con elevación sutil al hacer hover y atenuación con tachado al marcarse como completadas.
- Badges de nodo con bordes luminosos y punto indicador (`.badge-dot`).
- Pantalla vacía (*Empty state*) con ícono y mensaje explicativo cuando no existen tareas en Redis.

---

## 🧪 Pruebas y Resultados

### 1. Compilación de Producción con Vite
Se instalaron las dependencias base en el worktree y se ejecutó la compilación de producción:
```bash
$ npm run build

> podman-lab-frontend@1.0.0 build
> vite build

vite v5.4.21 building for production...
transforming...
✓ 33 modules transformed.
rendering chunks...
computing gzip size...
dist/index.html                   0.71 kB │ gzip:  0.40 kB
dist/assets/index-NtF6wdKD.css    9.70 kB │ gzip:  2.31 kB
dist/assets/index-KWYPGqBz.js   161.84 kB │ gzip: 51.34 kB
✓ built in 4.66s
```
* **Diagnóstico**: Compilación 100% limpia sin advertencias de sintaxis, variables sin resolver ni incompatibilidades de tipos.
* **Compatibilidad con `Containerfile`**: El proceso multi-stage de producción (`node:20-alpine -> nginx:alpine`) utiliza exactamente `npm run build` y la carpeta `dist/`, asegurando un despliegue sin modificaciones en Azure o local.

---

## 💡 Decisiones Arquitectónicas & Lecciones Aprendidas

1. **Poder del Desarrollo Basado en Contratos (API-First / Contract-First)**:
   - Al haber consensuado previamente el formato JSON de `/api/tasks` en `PLAN_TP1.md`, el equipo de frontend pudo construir y validar completamente la interfaz sin depender de que el backend en .NET 10 y Redis estuvieran listos o desplegados.
2. **Visibilidad Incontrastable del Cluster**:
   - En una arquitectura distribuida detrás de un balanceador de carga, el usuario raramente percibe qué nodo atiende cada operación. La incorporación de badges explícitos para `createdByNode` y `servedByNode` transforma una ToDo List convencional en una demostración viva de alta disponibilidad y persistencia desacoplada.
3. **Coexistencia sin Regresiones**:
   - La modularización en pestañas preserva las herramientas de Chaos Engineering (utilizadas para evidenciar OOM Kills y timeouts 504 en la defensa del TP) a la vez que sitúa al nuevo Tablero Distribuido como la cara visible principal del sistema.

---

## 📌 Próximos Pasos
- Integración con la **Etapa 1** (Backend .NET 10 + Redis en `compose.yaml`).
- Configuración y prueba del cluster local de 3 nodos balanceados con Nginx (Etapa 3) para observar la rotación de firmas en tiempo real.
