# 📓 Bitácora del Proyecto

Registro cronológico de avances, experimentos, decisiones arquitectónicas y aprendizajes durante el desarrollo del laboratorio de DevOps.

---

## 📋 Entradas Recientes

- [**2026-09-12: Despliegue Continuo (CD) en VM Linux con Environments**](/bitacora/2026-09-12-despliegue-continuo-vm-azure)
  - Registro de VM Linux en Azure DevOps Environments como agente Pull-based.
  - Arquitectura segura sin exposición de puertos SSH ni claves en variables.
  - Automatización del pull de imágenes OCI desde ACR y recreación de contenedores con Compose.
  - Smoke testing y validación de salud de Nginx.

- [**2026-09-12: Diseño e Implementación de CI/CD en Azure DevOps y SemVer**](/bitacora/2026-09-12-diseno-ci-cd-azure-devops)
  - Diseño del pipeline multi-stage (`azure-pipelines.yml`) separando CI y CD.
  - Automatización de Versionado Semántico mediante Conventional Commits.
  - Publicación segura en Azure Container Registry (`acrdevopsvalenzano.azurecr.io`).
  - Despliegue continuo y validación con Smoke Tests en la VM Linux.

- [**2026-09-08: Migración a .NET 10 (LTS) y Contenedorización Inmutable**](/bitacora/2026-09-08-migracion-dotnet-10)
  - Actualización del microservicio backend a .NET 10 LTS preservando el diseño *single-file* (Minimal API).
  - Actualización de imágenes base en `Containerfile` (`10.0-alpine`).
  - Aplicación de principios DevOps: inmutabilidad del host VM y encapsulación hermética de dependencias.
  - Actualización de `compose.yaml` y versionado semántico SemVer `2.0.0`.

- [**2026-09-07: Infraestructura en Azure (VM Linux + ACR) y Estrategia Incremental**](/bitacora/2026-09-07-migracion-azure-vm-acr)
  - Despliegue de VM Linux (`Standard_B2als_v2`) y Azure Container Registry en `Chile Central`.
  - Configuración de Docker Engine y Docker Compose nativos en Ubuntu 24.04.
  - Empaquetado y sincronización del repositorio limpio vía SCP.
  - Planificación de crecimiento por etapas y ruteo centralizado en Nginx.

- [**2026-08-31: Inicialización del Lab & Documentación**](/bitacora/2026-08-31-inicio-lab)
  - Puesta en marcha de la estructura base del proyecto.
  - Implementación de VitePress como motor de documentación técnica y bitácora.
  - Configuración de Podman Compose y Native Pods.

---

## 💡 ¿Cómo agregar una nueva entrada a la bitácora?

1. Crea un nuevo archivo en el directorio `docs/bitacora/` con el formato `AAAA-MM-DD-titulo-breve.md`.
2. Agrega la entrada a la lista en `docs/bitacora/index.md` y en el sidebar de `docs/.vitepress/config.mts`.
3. Seguí la siguiente estructura sugerida:

```markdown
# 🚀 [Título de la sesión o hito]

**Fecha**: AAAA-MM-DD  
**Autor**: Tu Nombre / Equipo  

---

## 🎯 Objetivos de la sesión
- Objetivo 1
- Objetivo 2

---

## 🛠️ Acciones Realizadas
- Detalle de lo implementado o probado...

---

## 🧪 Pruebas y Resultados
- Qué comandos ejecutaste y qué salidas obtuviste...

---

## 💡 Lecciones Aprendidas & Decisiones
- Qué funcionó, qué falló y por qué...

---

## 📌 Próximos Pasos
- Tareas pendientes para la próxima sesión.
```
