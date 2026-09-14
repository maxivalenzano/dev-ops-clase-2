# 🌐 2026-09-14: Configuración de Dominio Personalizado (IONOS DNS), IP Estática en Azure y Nginx Gateway

**Fecha**: 2026-09-14  
**Autor**: Maxi Valenzano  
**Hito**: Adquisición y vinculación del dominio personalizado `devops-maxivalenzano.com` a la infraestructura de Azure VM (`68.211.137.116`), configuración de registros DNS en IONOS, verificación de asignación de IP estática en Azure, actualización del virtual host en Nginx y sincronización completa de metadata en GitHub, Azure DevOps Wiki y pipelines de CD.

---

## 🎯 Objetivos de la sesión
- Vincular el dominio `devops-maxivalenzano.com` adquirido en IONOS con la máquina virtual de Azure (`vm-dev-ops`).
- Configurar la zona DNS autoritativa en IONOS con registros de tipo `A` y `CNAME`.
- Validar la persistencia de la dirección IP pública en Microsoft Azure (asignación Estática).
- Ajustar la directiva `server_name` en el Gateway de Nginx para reconocer el nuevo dominio y subdominio `www`.
- Reemplazar todas las referencias directas a la dirección IP pública por la nueva URL (`http://devops-maxivalenzano.com`) en `README.md`, pipelines, documentación y Azure DevOps Wiki.

---

## 🛠️ Procedimiento y Configuración Técnica

### 1. Configuración de Zona DNS en IONOS
En el panel de control de IONOS (`my.ionos.com`), se configuraron los siguientes registros DNS:

| Tipo | Host name | Valor / Apunta a | TTL | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `@` | `68.211.137.116` | 3600 s (1 hora) | Apunta el dominio raíz (`devops-maxivalenzano.com`) a la IP de la VM. |
| **CNAME** | `www` | `devops-maxivalenzano.com` | 3600 s (1 hora) | Enruta las peticiones con prefijo `www` al dominio raíz. |

Los registros preexistentes de correo electrónico (`MX`, `SPF/TXT`, `DKIM`, `DMARC`, `autodiscover`) se preservaron intactos para asegurar la operatividad del servicio de mail corporativo.

### 2. Verificación de IP Pública Estática en Microsoft Azure
En el portal de Azure (`portal.azure.com`), se auditó el recurso de dirección IP pública `vm-dev-ops-ip-4d98bec5`:
- **Asignación**: `Static` (Estática).
- **Garantía**: La IP `68.211.137.116` permanece inmutable ante reinicios, desasignaciones (*deallocate*) o mantenimientos programados del hipervisor.

### 3. Ajuste de Virtual Host en Nginx Gateway
En el archivo `nginx/nginx.conf`, se actualizó la directiva `server_name` para aceptar el tráfico entrante dirigido al nuevo dominio:

```nginx
server {
    listen 80;
    server_name devops-maxivalenzano.com www.devops-maxivalenzano.com localhost;

    # Proxy timeouts y enrutamiento a frontend SPA y cluster backend
    location / {
        proxy_pass http://frontend_server;
    }

    location /api/ {
        proxy_pass http://backend_cluster;
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
    }
}
```

### 4. Sincronización de Metadata y URLs en Ecosistema DevOps
1. **GitHub Repository**:
   - Actualización de la `homepageUrl` del repositorio vía GitHub CLI:
     ```bash
     gh repo edit maxivalenzano/dev-ops-clase-2 --homepage "http://devops-maxivalenzano.com"
     ```
2. **Azure DevOps Wiki**:
   - Actualización de la página `/Overview` en la wiki oficial `DevOps.wiki` destacando el nuevo dominio y URL en vivo.
3. **CI/CD Pipeline (`azure-pipelines.yml`)**:
   - Actualización de la descripción en el release automático de GitHub.
   - Parámetro `environment_url` en GitHub Deployments API apuntando a `http://devops-maxivalenzano.com`.
4. **Documentación y README**:
   - Actualización de shields y enlaces de acceso en vivo en el `README.md`.

---

## 🧪 Pruebas y Validación

1. **Resolución de Nombres DNS**:
   Se validó la propagación global mediante `Resolve-DnsName`:
   ```powershell
   Resolve-DnsName -Name devops-maxivalenzano.com -Server 8.8.8.8
   ```
   **Resultado**:
   ```text
   Name                               Type   TTL   Section    IPAddress
   ----                               ----   ---   -------    ---------
   devops-maxivalenzano.com           A      3600  Answer     68.211.137.116
   ```

2. **Acceso Web y Experiencia de Usuario**:
   - URL activa: [http://devops-maxivalenzano.com](http://devops-maxivalenzano.com).
   - Acceso al Frontend SPA en React 18, comunicación con endpoints `/api/tasks` y balanceo entre las réplicas backend.

---

## 💡 Lecciones Aprendidas
1. **Nomenclatura de Subdominios en Paneles DNS**: Al configurar un registro CNAME en IONOS, el campo *Host name* debe contener únicamente el subdominio (`www`), evitando colocar el FQDN completo para no duplicar el nombre de zona (`www.devops-maxivalenzano.com.devops-maxivalenzano.com`).
2. **Desacoplamiento IP vs FQDN**: El uso de un nombre de dominio desacopla por completo la identidad pública de la solución respecto de la IP del proveedor cloud, facilitando futuras migraciones o balanceadores de tráfico globales sin impacto al usuario final.
