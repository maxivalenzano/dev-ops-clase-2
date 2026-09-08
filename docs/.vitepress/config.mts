import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'DevOps & Podman Lab',
  description: 'Documentación técnica, arquitectura y bitácora del laboratorio de microservicios y contenedores',
  lang: 'es-AR',
  base: '/',
  lastUpdated: true,
  cleanUrls: true,

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'DevOps Lab',

    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: {
                buttonText: 'Buscar...',
                buttonAriaLabel: 'Buscar en la documentación'
              },
              modal: {
                noResultsText: 'No se encontraron resultados para',
                resetButtonTitle: 'Limpiar búsqueda',
                footer: {
                  selectText: 'para seleccionar',
                  navigateText: 'para navegar',
                  closeText: 'para cerrar'
                }
              }
            }
          }
        }
      }
    },

    nav: [
      { text: 'Inicio', link: '/' },
      { text: 'Arquitectura', link: '/general/overview' },
      { text: 'Backend', link: '/backend/' },
      { text: 'Frontend', link: '/frontend/' },
      { text: 'Infra & Pods', link: '/infrastructure/' },
      { text: 'Bitácora', link: '/bitacora/' }
    ],

    sidebar: {
      '/general/': [
        {
          text: 'Visión General',
          items: [
            { text: 'Arquitectura y Flujo', link: '/general/overview' },
            { text: 'Podman vs Docker', link: '/general/podman-vs-docker' }
          ]
        }
      ],
      '/backend/': [
        {
          text: 'Microservicio Backend',
          items: [
            { text: 'Descripción y Endpoints', link: '/backend/' },
            { text: 'Pruebas de Estrés y Chaos', link: '/backend/#chaos-engineering-y-estres' },
            { text: 'Gestión de Memoria y CPU', link: '/backend/#limites-de-recursos' }
          ]
        }
      ],
      '/frontend/': [
        {
          text: 'Cliente Frontend',
          items: [
            { text: 'Arquitectura React + Vite', link: '/frontend/' },
            { text: 'Contenedor Nginx SPA', link: '/frontend/#servidor-estatico-nginx' },
            { text: 'Panel de Control del Lab', link: '/frontend/#dashboard-interactivo' }
          ]
        }
      ],
      '/infrastructure/': [
        {
          text: 'Infraestructura y Red',
          items: [
            { text: 'Nginx Gateway & Proxy', link: '/infrastructure/' },
            { text: 'Balanceo de Carga y Timeouts', link: '/infrastructure/#balanceo-y-resiliencia' },
            { text: 'Podman Pods (Localhost)', link: '/infrastructure/#podman-pods-localhost-networking' }
          ]
        }
      ],
      '/bitacora/': [
        {
          text: 'Bitácora de Trabajo',
          items: [
            { text: 'Índice de Entradas', link: '/bitacora/' },
            { text: '2026-09-07: Infraestructura en Azure', link: '/bitacora/2026-09-07-migracion-azure-vm-acr' },
            { text: '2026-08-31: Inicialización del Lab', link: '/bitacora/2026-08-31-inicio-lab' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/maxivalenzano/dev-ops-clase-2' }
    ],

    footer: {
      message: 'Laboratorio de DevOps, Podman y Arquitectura de Microservicios.',
      copyright: 'Copyright © 2026'
    },

    docFooter: {
      prev: 'Página anterior',
      next: 'Próxima página'
    },

    outline: {
      label: 'En esta página',
      level: [2, 3]
    }
  }
});
