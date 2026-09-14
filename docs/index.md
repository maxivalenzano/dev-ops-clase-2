---
layout: home

hero:
  name: "DevOps & Podman Lab"
  text: "Laboratorio de Microservicios y Contenedores"
  tagline: "Arquitectura resiliente en Azure VM con Nginx, .NET 10, React 18, Redis, Portainer CE y CI/CD en 4 Stages."
  actions:
    - theme: brand
      text: 🎓 Ver Presentación Oficial
      link: /presentacion/
    - theme: alt
      text: 📄 Informe TP1
      link: /general/informe-tp1
    - theme: alt
      text: 📝 Bitácora de Trabajo
      link: /bitacora/

features:
  - icon: 🎓
    title: Presentación Técnica Integral
    details: "Síntesis ejecutiva de todo el ecosistema: Azure VM (IaaS), NSG, pipeline de 4 stages, registro dual ACR/GHCR y Portainer."
  - icon: 🚢
    title: Portainer CE & Observabilidad
    details: "Monitoreo visual de 10 contenedores en tiempo real sobre el puerto 9000, con métricas de CPU/RAM y soporte para Chaos Testing."
  - icon: 🛡️
    title: DevSecOps & SonarQube Cloud
    details: "Pipeline automatizado con cálculo SemVer dinámico, 42 tests xUnit, escaneo SAST y auditoría de vulnerabilidades con Trivy."
  - icon: ⚖️
    title: Nginx Gateway & Resiliencia
    details: "Clúster de 3 réplicas Frontend y 3 réplicas Backend con balanceo Round Robin, failover activo y timeout de 5 segundos."
  - icon: 🦭
    title: Podman & Pods Nativos
    details: "Comparativa entre contenedores rootless locales con red compartida localhost y orquestación con Docker Compose en Azure."
  - icon: 💥
    title: Chaos & Stress Testing
    details: "Simulación de consumo extremo de RAM para activar el OOM Killer del kernel Linux, saturación de CPU y degradación de salud."
---
