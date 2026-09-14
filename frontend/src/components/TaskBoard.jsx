import React, { useState, useEffect } from 'react';

// Helper para determinar estilos de color según el nodo
export function getNodeStyle(nodeName) {
  if (!nodeName) return { bg: 'rgba(148, 163, 184, 0.15)', border: '#64748b', text: '#94a3b8', label: 'Desconocido' };

  const name = String(nodeName).toLowerCase();
  if (name.includes('1')) {
    return {
      bg: 'rgba(59, 130, 246, 0.15)',
      border: 'var(--accent-blue, #3b82f6)',
      text: 'var(--accent-blue, #3b82f6)',
      badgeClass: 'node-badge-blue',
      label: nodeName
    };
  }
  if (name.includes('2')) {
    return {
      bg: 'rgba(16, 185, 129, 0.15)',
      border: 'var(--accent-green, #10b981)',
      text: 'var(--accent-green, #10b981)',
      badgeClass: 'node-badge-green',
      label: nodeName
    };
  }
  if (name.includes('3')) {
    return {
      bg: 'rgba(245, 158, 11, 0.15)',
      border: 'var(--accent-amber, #f59e0b)',
      text: 'var(--accent-amber, #f59e0b)',
      badgeClass: 'node-badge-amber',
      label: nodeName
    };
  }
  return {
    bg: 'rgba(168, 85, 247, 0.15)',
    border: 'var(--accent-purple, #a855f7)',
    text: 'var(--accent-purple, #a855f7)',
    badgeClass: 'node-badge-purple',
    label: nodeName
  };
}

export default function TaskBoard({ onLogEvent }) {
  const [tasks, setTasks] = useState([]);
  const [servedByNode, setServedByNode] = useState(null);
  const [totalCount, setTotalCount] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [errorMessage, setErrorMessage] = useState(null);
  const [filter, setFilter] = useState('all'); // 'all' | 'pending' | 'completed'

  const fetchTasks = async () => {
    setIsLoading(true);
    setErrorMessage(null);
    const start = performance.now();
    try {
      const res = await fetch('/api/tasks');
      const latency = Math.round(performance.now() - start);

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      }

      const data = await res.json();
      // data format: { servedByNode: "backend-dotnet-2", totalCount: 3, tasks: [...] }
      setServedByNode(data.servedByNode || 'Desconocido');
      setTotalCount(data.totalCount ?? (data.tasks ? data.tasks.length : 0));
      setTasks(Array.isArray(data.tasks) ? data.tasks : []);

      if (onLogEvent) {
        onLogEvent({
          method: 'GET',
          url: '/api/tasks',
          status: res.status,
          instance: data.servedByNode || 'Cluster',
          latency
        });
      }
    } catch (err) {
      const latency = Math.round(performance.now() - start);
      setErrorMessage(`No se pudo sincronizar con Redis / Backend: ${err.message}`);
      if (onLogEvent) {
        onLogEvent({
          method: 'GET',
          url: '/api/tasks',
          status: 0,
          instance: 'Network Error',
          latency,
          error: err.message
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchTasks();
  }, []);

  const handleCreateTask = async (e) => {
    e.preventDefault();
    const title = newTitle.trim();
    if (!title) return;

    setIsSubmitting(true);
    setErrorMessage(null);
    const start = performance.now();
    try {
      const res = await fetch('/api/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title })
      });
      const latency = Math.round(performance.now() - start);

      if (!res.ok) {
        throw new Error(`Error ${res.status} al crear tarea`);
      }

      const createdTask = await res.json();
      setNewTitle('');

      if (onLogEvent) {
        onLogEvent({
          method: 'POST',
          url: '/api/tasks',
          status: res.status,
          instance: createdTask.createdByNode || 'Cluster',
          latency
        });
      }

      // Refrescar lista completa para sincronizar estado de Redis y servedByNode
      await fetchTasks();
    } catch (err) {
      const latency = Math.round(performance.now() - start);
      setErrorMessage(`Error al crear la tarea en el cluster: ${err.message}`);
      if (onLogEvent) {
        onLogEvent({
          method: 'POST',
          url: '/api/tasks',
          status: 0,
          instance: 'Network Error',
          latency,
          error: err.message
        });
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleTask = async (task) => {
    const start = performance.now();
    try {
      const res = await fetch(`/api/tasks/${task.id}/toggle`, {
        method: 'PUT'
      });
      const latency = Math.round(performance.now() - start);

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }

      // Optimistic update local
      setTasks((prev) =>
        prev.map((t) => (t.id === task.id ? { ...t, isCompleted: !t.isCompleted } : t))
      );

      if (onLogEvent) {
        onLogEvent({
          method: 'PUT',
          url: `/api/tasks/${task.id}/toggle`,
          status: res.status,
          instance: 'Cluster (Redis)',
          latency
        });
      }
    } catch (err) {
      setErrorMessage(`Error al actualizar estado de la tarea: ${err.message}`);
      fetchTasks();
    }
  };

  const handleDeleteTask = async (taskId) => {
    const start = performance.now();
    try {
      const res = await fetch(`/api/tasks/${taskId}`, {
        method: 'DELETE'
      });
      const latency = Math.round(performance.now() - start);

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }

      setTasks((prev) => prev.filter((t) => t.id !== taskId));
      setTotalCount((prev) => Math.max(0, prev - 1));

      if (onLogEvent) {
        onLogEvent({
          method: 'DELETE',
          url: `/api/tasks/${taskId}`,
          status: res.status,
          instance: 'Cluster (Redis)',
          latency
        });
      }
    } catch (err) {
      setErrorMessage(`Error al eliminar tarea: ${err.message}`);
      fetchTasks();
    }
  };

  const filteredTasks = tasks.filter((t) => {
    if (filter === 'pending') return !t.isCompleted;
    if (filter === 'completed') return t.isCompleted;
    return true;
  });

  const completedCount = tasks.filter((t) => t.isCompleted).length;
  const pendingCount = tasks.length - completedCount;
  const servedStyle = getNodeStyle(servedByNode);

  return (
    <div className="taskboard-container">
      {/* Banner de Información de Arquitectura y Firmas de Nodo */}
      <div className="card taskboard-header-card">
        <div className="taskboard-header-top">
          <div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span>📋</span> Tablero Distribuido con Persistencia Redis
            </h2>
            <p className="card-desc" style={{ marginTop: '0.35rem' }}>
              Demostración de <strong>persistencia centralizada en memoria</strong> y <strong>balanceo de carga</strong>. Cada solicitud es distribuida por Nginx hacia los nodos backend disponibles y estampada con la firma inmutable de la instancia receptora.
            </p>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
            {/* Indicador específico de qué réplica backend atendió esta consulta */}
            {servedByNode && (
              <div
                className="read-signature-badge"
                style={{ backgroundColor: servedStyle.bg, borderColor: servedStyle.border }}
                title="Instancia backend específica que atendió esta lectura de Redis (Nginx balancea cada consulta)"
              >
                <span className="badge-dot" style={{ backgroundColor: servedStyle.text }} />
                <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Consulta servida por:</span>
                <strong className="mono" style={{ color: servedStyle.text, fontSize: '0.85rem' }}>
                  {servedByNode}
                </strong>
              </div>
            )}

            <button
              onClick={fetchTasks}
              disabled={isLoading}
              style={{ fontSize: '0.8rem', padding: '0.4rem 0.75rem' }}
              title="Re-consultar tareas en Redis"
            >
              {isLoading ? '⏳ Sincronizando...' : '🔄 Recargar Tareas'}
            </button>
          </div>
        </div>

        {/* Contadores de Estado de Tareas */}
        <div className="taskboard-stats-row">
          <div className="task-stat-item">
            <span className="task-stat-label">Almacenadas en Redis</span>
            <span className="task-stat-num mono">{totalCount}</span>
          </div>
          <div className="task-stat-item">
            <span className="task-stat-label">Pendientes por Procesar</span>
            <span className="task-stat-num mono" style={{ color: 'var(--accent-amber)' }}>{pendingCount}</span>
          </div>
          <div className="task-stat-item">
            <span className="task-stat-label">Completadas con Éxito</span>
            <span className="task-stat-num mono" style={{ color: 'var(--accent-green)' }}>{completedCount}</span>
          </div>
        </div>
      </div>

      {/* Alerta de Error de Conexión */}
      {errorMessage && (
        <div className="taskboard-alert warning">
          <span>⚠️ {errorMessage}</span>
          <button onClick={fetchTasks} style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem', marginLeft: 'auto' }}>
            Reintentar Conexión
          </button>
        </div>
      )}

      {/* Formulario de Creación de Tarea */}
      <div className="card task-create-card">
        <form onSubmit={handleCreateTask} className="task-create-form">
          <input
            type="text"
            className="task-input"
            placeholder="Escribe una tarea para el cluster (ej. 'Verificar réplicas de ChaosNet en Azure VM')..."
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            disabled={isSubmitting}
          />
          <button type="submit" className="primary" disabled={isSubmitting || !newTitle.trim()}>
            {isSubmitting ? '⏳ Guardando en Redis...' : '➕ Guardar en Cluster'}
          </button>
        </form>
        <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          💡 Cada tarea se persiste en Redis y queda sellada con el nodo backend que atendió el <code className="mono">POST</code> (<code className="mono">createdByNode</code>). En ChaosNet Lab, los datos se preservan ante caídas de réplicas.
        </p>
      </div>

      {/* Filtros de Lista de Tareas */}
      <div className="task-list-header">
        <div className="task-filter-group">
          <button
            className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
            onClick={() => setFilter('all')}
          >
            📑 Todas ({tasks.length})
          </button>
          <button
            className={`filter-btn ${filter === 'pending' ? 'active' : ''}`}
            onClick={() => setFilter('pending')}
          >
            ⏳ Pendientes ({pendingCount})
          </button>
          <button
            className={`filter-btn ${filter === 'completed' ? 'active' : ''}`}
            onClick={() => setFilter('completed')}
          >
            ✅ Completadas ({completedCount})
          </button>
        </div>
      </div>

      {/* Grilla / Lista de Tareas */}
      {filteredTasks.length === 0 ? (
        <div className="card empty-tasks-card">
          <div className="empty-icon">📭</div>
          <h3 className="empty-title">No hay tareas en esta vista</h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', maxWidth: '480px' }}>
            {tasks.length === 0
              ? 'El almacén en Redis no contiene registros aún. Agrega la primera tarea arriba para comprobar qué nodo backend procesa la escritura y observar la firma generada.'
              : 'No existen tareas que coincidan con el filtro seleccionado.'}
          </p>
        </div>
      ) : (
        <div className="task-grid">
          {filteredTasks.map((task) => {
            const createdStyle = getNodeStyle(task.createdByNode);
            const formattedDate = task.createdAt
              ? new Date(task.createdAt).toLocaleString('es-AR', {
                  dateStyle: 'short',
                  timeStyle: 'medium'
                })
              : 'Fecha no disponible';

            return (
              <div
                key={task.id}
                className={`task-card ${task.isCompleted ? 'task-completed' : ''}`}
              >
                <div className="task-card-main">
                  <label className="task-checkbox-container">
                    <input
                      type="checkbox"
                      checked={Boolean(task.isCompleted)}
                      onChange={() => handleToggleTask(task)}
                    />
                    <span className="checkmark" />
                  </label>

                  <div className="task-content">
                    <div className="task-title-row">
                      <span className="task-title">{task.title}</span>
                    </div>

                    <div className="task-metadata">
                      {/* Badge con firma de nodo creador */}
                      <span
                        className={`node-badge ${createdStyle.badgeClass || ''}`}
                        title={`Tarea creada y procesada por la instancia: ${task.createdByNode}`}
                      >
                        <span className="badge-dot" style={{ backgroundColor: createdStyle.text }} />
                        <span className="badge-prefix">Creado por:</span>
                        <strong className="mono">{task.createdByNode || 'Desconocido'}</strong>
                      </span>

                      <span className="task-date mono" title={task.createdAt}>
                        🕒 {formattedDate}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="task-card-actions">
                  <button
                    className="delete-task-btn"
                    title="Eliminar tarea de Redis"
                    onClick={() => handleDeleteTask(task.id)}
                  >
                    🗑️
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
