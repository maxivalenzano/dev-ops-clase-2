---
layout: home

hero:
  name: "DevOps Lab"
  text: "Laboratorio de Microservicios y Contenedores"
  tagline: "Laboratorio con Nginx, .NET 10, React 18 y Redis. Nube AWS y CI/CD implementados y validados."
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
    - theme: alt
      text: 🌐 Aplicación EC2
      link: http://18.216.227.211

features:
  - icon: 🎓
    title: Presentación Técnica Integral
    details: "CI/CD 81 y la persistencia de tareas tras rollback, nueva entrega y reinicio real de Ubuntu están validados."
  - icon: 🚢
    title: Portainer CE & Observabilidad
    details: "Panel para administrar el stack Compose y observar sus contenedores durante las pruebas."
  - icon: 🛡️
    title: DevSecOps & SonarQube Cloud
    details: "Pipeline de Azure DevOps con versionado SemVer, pruebas xUnit, análisis SonarCloud y auditoría Trivy."
  - icon: ⚖️
    title: Nginx Gateway & Resiliencia
    details: "Tres réplicas de frontend y tres de backend tras Nginx, con Redis compartido y timeout de 5 segundos."
  - icon: 🦭
    title: "Podman local y Docker en EC2"
    details: "Compose usa Podman localmente y Docker en Ubuntu EC2. La versión 3.0.0-build.81 está desplegada."
  - icon: 💥
    title: Chaos & Stress Testing
    details: "Simulación de consumo extremo de RAM para activar el OOM Killer del kernel Linux, saturación de CPU y degradación de salud."
---
