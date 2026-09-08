# 🚀 2026-08-31: Inicialización del Lab & Documentación

**Fecha**: 2026-08-31  
**Hito**: Puesta en marcha de la arquitectura base e integración de VitePress.

---

## 🎯 Objetivos de la sesión
- Estructurar el repositorio con microservicios (Backend Node.js, Frontend React Vite, Gateway Nginx).
- Habilitar soporte para despliegues tanto con **Podman Compose** (red bridge) como con **Podman Pods** nativos (red compartida sobre localhost).
- Diseñar e implementar un sistema de documentación técnica y bitácora de desarrollo con **VitePress**.

---

## 🛠️ Acciones Realizadas

1. **Diseño de Microservicios y Chaos Testing**:
   - Se crearon endpoints en Express para simular carga de CPU, retención de memoria (para inducir OOM Killer) y demoras de respuesta.
   - Se configuró el cliente en React 18 para monitorear en vivo qué nodo del backend atiende cada solicitud.

2. **Infraestructura con Nginx**:
   - Configuración de balanceo de carga `upstream` entre dos réplicas (`backend-1` y `backend-2`).
   - Ajuste de `proxy_read_timeout 5s;` para validar caídas de red.
   - Configuración de respuestas de error JSON personalizadas para `502` y `504`.

3. **Configuración de VitePress**:
   - Inicialización del paquete de documentación en la carpeta `/docs`.
   - Creación de pestañas temáticas: *Arquitectura General*, *Backend*, *Frontend*, *Infraestructura* y *Bitácora*.
   - Configuración de búsqueda local rápida y tema oscuro.

---

## 🧪 Pruebas y Resultados

- Se probó la compilación estática de VitePress (`npm run docs:build`), verificando que los enlaces y metadatos se resuelven sin errores.
- Se verificó que los scripts de automatización de Podman permiten levantar y bajar el ecosistema en entornos Windows y Linux.

---

## 💡 Decisiones Técnicas

- **VitePress vs Docusaurus**: Se seleccionó VitePress para minimizar el overhead de dependencias y tiempos de inicio, manteniendo alineación con el stack frontend existente (Vite).
- **Aislamiento en `/docs`**: Se decidió aislar la documentación en su propia carpeta para evitar ensuciar el `package.json` raíz o mezclar dependencias de frontend/backend.

---

## 📌 Próximos Pasos
- [ ] Ejecutar pruebas de carga sostenida con Apache Bench (`ab`) o K6.
- [ ] Documentar escenarios de recuperación ante desastres cuando una réplica muere por OOM.
