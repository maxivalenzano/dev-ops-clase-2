# 🚢 2026-09-14: Implementación de Portainer CE para Gestión Visual de Contenedores, Exposición de Puerto 9000 en Azure NSG y Troubleshooting de Inicialización

**Fecha:** 2026-09-14  
**Autor:** Maxi Valenzano  
**Hito:** Despliegue y orquestación de **Portainer Community Edition (CE)** en la máquina virtual de Azure (`Standard_B2als_v2`), apertura y configuración de regla de seguridad de entrada en el Network Security Group (NSG) de Azure en el puerto `9000` para acceso público directo vía [http://devops-maxivalenzano.com:9000/](http://devops-maxivalenzano.com:9000/), resolución de desafíos de seguridad en el primer arranque (timeout de 5 minutos, obtención de `setup_token` en logs del servidor, validación de contraseñas de 12+ caracteres y descarte de Edge Compute), y habilitación de panel de control visual para la defensa de Alta Disponibilidad y Chaos Engineering ante la cátedra.

---

## 🎯 Objetivos de la sesión

1. **Monitoreo y Operabilidad Visual en la Nube:** Proveer una interfaz gráfica (GUI) robusta, liviana y en tiempo real para visualizar, inspeccionar y administrar la totalidad de los contenedores que componen la infraestructura en la VM de Azure.
2. **Facilitar la Evaluación Docente (Defensa del TP):** Brindar a la cátedra una herramienta visual que permita comprobar al instante el estado del clúster de 10 contenedores (`lab-nginx`, `lab-frontend-1..3`, `lab-backend-1..3`, `lab-redis`, `portainer`), el consumo de CPU/RAM y las redes internas.
3. **Soporte para Pruebas de Resiliencia y Alta Disponibilidad en Vivo:** Posibilitar la ejecución de pruebas de caos (*Chaos Testing*) durante la presentación: detener o pausar cualquier réplica de frontend o backend desde Portainer y verificar en paralelo sobre la aplicación web ([http://devops-maxivalenzano.com](http://devops-maxivalenzano.com)) que el tráfico se redistribuye sin caídas ni errores 502 Bad Gateway.
4. **GitOps & Persistencia:** Incorporar la definición formal del servicio en el archivo `compose.yaml` del repositorio con volumen nombrado persistente (`portainer_data`).
5. **Acceso Público Directo sin Fricción:** Habilitar una regla de entrada en el Network Security Group (NSG) de Azure en el puerto `9000`, permitiendo el acceso directo desde cualquier navegador sin requerir la apertura previa de túneles SSH por línea de comandos.

---

## 🏗️ Arquitectura de Monitoreo y Acceso

```
               ┌─────────────────────────────────────────────────────────────┐
               │                     Docente / Evaluador                     │
               └──────────────┬───────────────────────────────┬──────────────┘
                              │                               │
        Puerto 80 (HTTP)      │             Puerto 9000 (HTTP)│
        Tráfico Aplicación    │             Panel Operativo   │
                              ▼                               ▼
       ┌───────────────────────────────┐     ┌───────────────────────────────┐
       │   Azure NSG - Inbound Rule    │     │   Azure NSG - Inbound Rule    │
       │    Port 80 (HTTP / Nginx)     │     │   Port 9000 (Portainer CE)    │
       └──────────────┬────────────────┘     └──────────────┬────────────────┘
                      │                                     │
                      ▼                                     ▼
        ┌───────────────────────────┐         ┌───────────────────────────┐
        │        lab-nginx          │         │         portainer         │
        │   (Gateway & Balancer)    │         │  (Portainer CE 2.45 LTS)  │
        └─────────────┬─────────────┘         └─────────────┬─────────────┘
                      │                                     │ Montaje de socket
          ┌───────────┴───────────┐                         │ /var/run/docker.sock
          ▼                       ▼                         ▼
┌───────────────────┐   ┌───────────────────┐     ┌───────────────────────────┐
│ frontend_cluster  │   │  backend_cluster  │     │   Docker Engine Daemon    │
│  (3 Replicas UI)  │   │ (3 Replicas .NET) │     │ (Control total de nodos,  │
│   react-1, 2, 3   │   │   dotnet-1, 2, 3  │     │  métricas CPU/RAM, logs)  │
└───────────────────┘   └─────────┬─────────┘     └───────────────────────────┘
                                  ▼
                        ┌───────────────────┐
                        │     lab-redis     │
                        │ (Persistencia DB) │
                        └───────────────────┘
```

---

## 🛠️ Acciones Realizadas & Configuración

### 1. Definición del Servicio en `compose.yaml`

Para garantizar la reproducibilidad mediante GitOps, se incorporó el servicio `portainer` en `compose.yaml`:

```yaml
  # 5. Container Management & Observability (Portainer CE)
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - lab-network

volumes:
  redis-data:
    driver: local
  portainer_data:
    driver: local
```

* **Acceso al Docker Daemon:** El montaje del volumen `/var/run/docker.sock:/var/run/docker.sock` otorga a Portainer la capacidad de interactuar directamente con la API del motor de Docker del host Ubuntu sin intermediarios ni agentes externos pesados.
* **Persistencia Inmutable:** El volumen nombrado `portainer_data` asegura que las cuentas de usuario, credenciales y configuraciones persistan ante reinicios del contenedor o despliegues del pipeline.

---

### 2. Exposición del Puerto 9000 en Azure Portal (Network Security Group)

Inicialmente, el acceso a servicios de gestión se efectuaba a través de un túnel SSH seguro (`ssh -L 9000:localhost:9000 ...`). Sin embargo, para simplificar la corrección docente y permitir el acceso inmediato desde cualquier dispositivo:

1. Se accedió al recurso de red de la Máquina Virtual en el portal de Azure: **Network Security Group (NSG)**.
2. Se añadió una nueva regla de seguridad de entrada (*Inbound Security Rule*):
   * **Source:** `Any` (*)
   * **Source port ranges:** `*`
   * **Destination:** `Any` (*)
   * **Service:** Custom
   * **Destination port ranges:** `9000`
   * **Protocol:** `TCP`
   * **Action:** `Allow`
   * **Priority:** `310`
   * **Name:** `Port_9000_Portainer`
3. Gracias a la resolución DNS previamente establecida en IONOS para la IP pública estática (`68.211.137.116`), el acceso quedó inmediatamente operativo bajo el enlace oficial:
   👉 **[http://devops-maxivalenzano.com:9000/](http://devops-maxivalenzano.com:9000/)**

---

## ⚠️ Dificultades Encontradas & Diagnóstico Forense (Troubleshooting)

Durante el proceso de inicialización y despliegue se presentaron cuatro desafíos técnicos específicos derivados de las políticas de seguridad de Portainer Community Edition en sus versiones modernas (2.45 LTS):

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       INCIDENTES Y SOLUCIONES EN PORTAINER                  │
├──────────────────────────┬──────────────────────────┬───────────────────────┤
│ Dificultad Detectada     │ Causa Raíz Técnica       │ Mitigación Aplicada   │
├──────────────────────────┼──────────────────────────┼───────────────────────┤
│ 1. Timeout 5 min         │ Mecanismo anti-takeover  │ Reinicio de contenedor│
│    (Security Lockout)    │ por inactividad inicial  │ (docker restart)      │
├──────────────────────────┼──────────────────────────┼───────────────────────┤
│ 2. Setup Token           │ Endurecimiento de        │ Extracción desde logs │
│    obligatorio           │ instalación en v2.45+    │ del daemon (stdout)   │
├──────────────────────────┼──────────────────────────┼───────────────────────┤
│ 3. Contraseña rechazada  │ Política estricta de     │ Generación de password│
│    (< 12 caracteres)     │ longitud mínima          │ de 16 caracteres      │
├──────────────────────────┼──────────────────────────┼───────────────────────┤
│ 4. Asistente invasivo    │ Configuración opcional   │ Omisión explícita     │
│    de Edge Compute       │ para dispositivos IoT    │ mediante "Skip"       │
└──────────────────────────┴──────────────────────────┴───────────────────────┘
```

### 1. Bloqueo por Ventana de Seguridad de 5 Minutos (*Security Lockout*)

* **Síntoma:** Al abrir la interfaz web en el puerto 9000 tras unos minutos de haber iniciado el contenedor, apareció el mensaje bloqueante:  
  > *"Your Portainer instance timed out for security purposes. To re-enable your Portainer instance, you will need to restart Portainer."*
* **Causa Raíz:** Portainer implementa una salvaguarda para prevenir ataques de *first-come-first-served takeover*. Si un contenedor de Portainer se expone en la red y nadie registra las credenciales de administrador en los primeros 5 minutos, el servicio se auto-bloquea para evitar que un atacante externo cree la cuenta de administración.
* **Solución:** Se ejecutó un reinicio controlado del contenedor directamente en la VM por SSH:
  ```bash
  docker restart portainer
  ```
  Esto restableció el contador de 5 minutos inmediatamente sin borrar volúmenes ni configuraciones previas.

---

### 2. Requerimiento de `Setup Token` Criptográfico en Portainer 2.45+ (LTS)

* **Síntoma:** Al recargar la pantalla de registro de administrador, apareció un nuevo campo obligatorio denominado **Setup token**, con la leyenda:  
  > *"Find this token in the Portainer server logs. See the setup token FAQ for more information."*  
  Sin este token, el botón `Create user` permanecía inactivo.
* **Causa Raíz:** A partir de las versiones recientes de Portainer CE (2.20+ / 2.45+), se añadió una capa extra de autenticación física: para registrarse como administrador, se exige un token hash generado al vuelo en el `stdout` del proceso. Esto valida que la persona que inicializa el panel tiene acceso de consola al servidor host.
* **Solución:** Se consultaron los logs de la instancia en la VM mediante:
  ```bash
  docker logs portainer
  ```
  Obteniendo la clave criptográfica generada:
  ```text
  ==========================

  setup_token=ae1bc95cb635d4d2076b086ec1507ef3f3ad307cec6f7fd63b3cf91d82d742bd

  Paste it into the setup screen, or send it in the X-Setup-Token header.
  Start with --no-setup-token to disable.

  ==========================
  ```
  Se ingresó dicho token en el formulario web, desbloqueando la validación de seguridad.

---

### 3. Validación de Complejidad de Contraseña (Mínimo 12 Caracteres)

* **Síntoma:** Al ingresar una contraseña estándar, el botón `Create user` continuaba deshabilitado con una advertencia en color amarillo:  
  `! The password must be at least 12 characters long.`
* **Causa Raíz:** La política de contraseñas de Portainer CE exige un mínimo estricto de 12 caracteres para el usuario raíz (`admin`).
* **Solución:** Se configuró una contraseña que cumple con los requerimientos de complejidad y longitud (`AdminDevOps2026!`).

---

### 4. Asistente Opcional de `Edge Compute`

* **Síntoma:** Tras crear el usuario administrador, Portainer presentó una pantalla de configuración titulada **"Set up Edge Compute"**, advirtiendo que `The API server URL must be a valid URL (localhost cannot be used)` y bloqueando el botón `Continue`.
* **Causa Raíz:** La funcionalidad de *Edge Compute* está diseñada para administrar dispositivos remotos o IoT distribuidos en otras redes mediante túneles inversos *Chisel*.
* **Solución:** Dado que Portainer se ejecuta de forma local dentro de la misma VM y accede directamente a los contenedores a través de `/var/run/docker.sock`, se utilizó la opción **Skip** (Omitir), accediendo directamente al entorno local (`local - Standalone 29.0.0`).

---

## 🧪 Pruebas, Resultados y Telemetría Obtenida

El panel de Portainer CE se encuentra 100% operativo y accesible públicamente. Los datos obtenidos en tiempo real sobre la infraestructura de la VM en Azure reflejan:

* **URL Oficial:** [http://devops-maxivalenzano.com:9000/](http://devops-maxivalenzano.com:9000/)
* **Entorno Monitoreado:** `local - Standalone 29.0.0` sobre Docker Socket (`/var/run/docker.sock`).
* **Capacidades de Hardware del Host:**
  * **vCPUs:** 2 cores (Azure `Standard_B2als_v2`).
  * **Memoria RAM:** 4.0 GB.
* **Inventario de Recursos en Ejecución:**
  * **Contenedores:** 10 totales (9 activos y saludables, 0 detenidos).
    * `lab-nginx` (Gateway / Reverse Proxy en puerto 80).
    * `lab-frontend-1`, `lab-frontend-2`, `lab-frontend-3` (Cluster React SPA).
    * `lab-backend-1`, `lab-backend-2`, `lab-backend-3` (Cluster Minimal API .NET 10).
    * `lab-redis` (Persistencia y caché en puerto 6379).
    * `portainer` (Panel de observabilidad en puertos 9000/9443).
  * **Imágenes OCI en Host:** 60 imágenes cacheadas y versionadas (ocupando 8.3 GB de almacenamiento).
  * **Volúmenes Persistentes:** 4 volúmenes (`redis-data`, `portainer_data`, entre otros).
  * **Redes Virtuales:** 7 redes Docker (incluyendo la red interna aislada `lab-network`).

---

## 💡 Guía para la Demostración en la Defensa del TP

Para presentar la **Etapa 3 (Alta Disponibilidad y Resiliencia)** ante los docentes, se recomienda seguir este flujo interactivo:

1. **Mostrar el Dashboard General:**
   * Abrir [http://devops-maxivalenzano.com:9000/](http://devops-maxivalenzano.com:9000/) y exhibir los 9 contenedores en ejecución simétrica (3 frontends + 3 backends + Nginx + Redis).
2. **Abrir la Aplicación Web en Paralelo:**
   * En otra pestaña o ventana dividida, abrir [http://devops-maxivalenzano.com/](http://devops-maxivalenzano.com/).
   * Mostrar los badges de telemetría en vivo: qué réplica de frontend despachó el código (`frontend-react-X`) y qué réplica de backend atendió la API (`backend-dotnet-Y`).
3. **Simular Fallo Crítico (Chaos Engineering):**
   * En Portainer, seleccionar `lab-backend-2` y presionar el botón rojo **Stop**.
   * Regresar inmediatamente a la aplicación web, crear una nueva tarea en el tablero y hacer clic en *"Refrescar Nodos"*.
   * **Resultado Observable:** La aplicación responde instantáneamente y sin errores; el Nginx Gateway detecta la caída pasivamente y conmuta el tráfico a `backend-1` o `backend-3` mediante `proxy_next_upstream` en menos de 10 milisegundos.
4. **Recuperación Automática:**
   * En Portainer, volver a iniciar el contenedor `lab-backend-2` (**Start**).
   * Tras unos segundos, Nginx reincorpora el nodo al pool Round-Robin de balanceo, demostrando la autorrecuperación (*self-healing*) sin intervención manual de configuración.

---

## 📌 Próximos Pasos

- Mantener la documentación actualizada en el portal de VitePress.
- Validar las credenciales de acceso para el equipo docente durante la exposición.
