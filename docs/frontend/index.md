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

## Despliegue actual

La versión `3.0.0-build.81` está desplegada en [http://18.216.227.211](http://18.216.227.211) detrás del gateway Nginx en EC2. Las pruebas de despliegue confirmaron respuestas `frontend-info` de las tres réplicas frontend. CI/CD 81 completó sus cuatro etapas.

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
1. **Monitor de instancias**: Muestra la réplica frontend y el backend que atendió la última consulta.
2. **Pruebas de estrés**: Permite generar solicitudes concurrentes, demorar respuestas, consumir CPU y alternar el estado de salud de un backend.
3. **Tablero distribuido**: Crea, completa y elimina tareas almacenadas en Redis y muestra qué réplica las atendió.

En local, el stack completo se levanta con Podman Compose desde la raíz del repositorio: `podman compose up --build -d`.
