# 🖥️ Cliente Frontend (React + Vite)

El frontend proporciona un panel de control interactivo para interactuar con la infraestructura del laboratorio.

---

## 🏗️ Arquitectura y Tecnologías

- **Framework**: React 18
- **Tooling**: Vite (Fast HMR & Optimized Production Build)
- **Estilos**: Vanilla CSS con variables modernas, diseño responsive y tema oscuro por defecto.
- **Servidor Web**: Nginx Alpine (`nginx:alpine`) para entrega de archivos estáticos.

---

## 🐳 Servidor Estático Nginx

En producción y dentro del contenedor, el frontend se compila con `npm run build` y los archivos estáticos resultantes en `dist/` se copian al contenedor Nginx.

El `nginx.conf` del frontend se encarga de:
- Servir los archivos en el puerto `8081` (o `80` en modo compose).
- Habilitar soporte para Single Page Application (**SPA Routing**) mediante `try_files $uri $uri/ /index.html;`.

```nginx
server {
    listen 8081;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 📊 Dashboard Interactivo

El dashboard incluye las siguientes secciones funcionales:
1. **Live Instance Monitor**: Identifica qué réplica del backend (`backend-node-1` o `backend-node-2`) respondió a la petición.
2. **Stress Controls**: Botones interactivos para disparar CPU stress, consumir memoria RAM en bloques de 30MB/60MB, o alternar el health check.
3. **Round Robin Tester**: Dispara ráfagas de 10 peticiones concurrentes para visualizar el reparto de carga equitativo.
4. **Timeout Simulator**: Dispara requests de 6 segundos para validar el error `504 Gateway Timeout` generado por Nginx.
