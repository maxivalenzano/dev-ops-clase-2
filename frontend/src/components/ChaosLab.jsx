import React from 'react';

export default function ChaosLab({
  serverInfo,
  instanceCounts,
  stats,
  logs,
  onResetStats,
  isRunningLoad,
  batchCount,
  setBatchCount,
  concurrency,
  setConcurrency,
  onRunLoadTest,
  delayMs,
  setDelayMs,
  onTestDelay,
  stressDuration,
  onTriggerCpuStress,
  memoryMB,
  onTriggerMemoryStress,
  onClearMemory,
  onToggleHealth
}) {
  return (
    <div className="chaos-container">
      {/* Barra Superior de Métricas en Tiempo Real */}
      <div className="stats-grid">
        <div className="stat-box" title="Total de solicitudes enviadas en esta sesión">
          <span className="stat-label">Peticiones Totales</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-blue)' }}>{stats.total}</span>
        </div>
        <div className="stat-box" title="Respuestas HTTP con código 2xx">
          <span className="stat-label">Exitosas (2xx)</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-green)' }}>{stats.success}</span>
        </div>
        <div className="stat-box" title="Respuestas con errores de cliente o servidor (4xx / 5xx / 0)">
          <span className="stat-label">Errores (4xx / 5xx)</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-rose)' }}>{stats.errors}</span>
        </div>
        <div className="stat-box" title="Tiempo promedio de ida y vuelta (Round-Trip Time)">
          <span className="stat-label">Latencia Media</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-amber)' }}>{stats.avgLatency} ms</span>
        </div>
      </div>

      {/* Grilla Principal de Experimentos */}
      <div className="grid">
        {/* Distribución de Carga del Balanceador Nginx */}
        <div className="card">
          <div className="card-title">
            <span>⚖️ Distribución Upstream (Nginx)</span>
            <button onClick={onResetStats} style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }} title="Reiniciar estadísticas acumuladas">
              Limpiar
            </button>
          </div>
          <p className="card-desc">
            Nginx distribuye las peticiones entre las réplicas backend disponibles mediante el algoritmo de <strong>Round-Robin</strong>:
          </p>
          <div className="dist-list">
            {Object.keys(instanceCounts).length === 0 ? (
              <p className="mono" style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                Sin peticiones registradas aún. Dispara una prueba de carga para observar el reparto.
              </p>
            ) : (
              Object.entries(instanceCounts).map(([inst, count]) => {
                const percentage = stats.total > 0 ? Math.round((count / stats.total) * 100) : 0;
                return (
                  <div key={inst} className="dist-item">
                    <div className="dist-header mono">
                      <span><strong>{inst}</strong></span>
                      <span>{count} reqs ({percentage}%)</span>
                    </div>
                    <div className="dist-bar-bg">
                      <div className="dist-bar-fill" style={{ width: `${percentage}%` }} />
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {serverInfo && (
            <div className="info-card-box mono">
              <div style={{ color: 'var(--accent-cyan)', fontWeight: 600 }}>Última Réplica Activa:</div>
              <div>Host: <strong>{serverInfo.hostname}</strong> (PID {serverInfo.pid})</div>
              <div>Puerto: <strong>{serverInfo.port}</strong> | Uptime: {serverInfo.uptimeSeconds}s</div>
              <div>Memoria RSS: <strong>{serverInfo.memory?.rssMB} MB</strong> (Buffers: {serverInfo.memory?.totalBuffersRetainedMB} MB)</div>
            </div>
          )}
        </div>

        {/* Generador de Carga Concurrente */}
        <div className="card">
          <div className="card-title">
            <span>⚡ Generador de Carga Concurrente</span>
          </div>
          <p className="card-desc">
            Envía ráfagas HTTP concurrentes sobre <code className="mono">/api/info</code> para auditar el comportamiento del balanceador y la latencia del cluster:
          </p>
          <div className="input-row">
            <label style={{ flex: 1 }}>Peticiones:</label>
            <select value={batchCount} onChange={(e) => setBatchCount(Number(e.target.value))}>
              <option value={10}>10 peticiones</option>
              <option value={50}>50 peticiones</option>
              <option value={100}>100 peticiones</option>
              <option value={250}>250 peticiones</option>
            </select>
          </div>
          <div className="input-row">
            <label style={{ flex: 1 }}>Concurrencia:</label>
            <select value={concurrency} onChange={(e) => setConcurrency(Number(e.target.value))}>
              <option value={1}>1 hilo (Secuencial)</option>
              <option value={5}>5 hilos en paralelo</option>
              <option value={10}>10 hilos en paralelo</option>
              <option value={20}>20 hilos en paralelo</option>
            </select>
          </div>
          <button className="primary" onClick={onRunLoadTest} disabled={isRunningLoad} style={{ marginTop: 'auto' }}>
            {isRunningLoad ? '⏳ Generando Carga...' : '▶ Disparar Prueba de Carga'}
          </button>
        </div>

        {/* Demoras y Timeouts en la Puerta de Enlace */}
        <div className="card">
          <div className="card-title">
            <span>⏱️ Inyección de Demora y Gateway Timeout</span>
          </div>
          <p className="card-desc">
            Nginx tiene configurado un límite de espera de <strong>5 segundos</strong>. Si el backend demora más de 5s, el proxy aborta la conexión y devuelve <code>504 Gateway Timeout</code>.
          </p>
          <div className="input-row">
            <label style={{ flex: 1 }}>Demora artificial:</label>
            <select value={delayMs} onChange={(e) => setDelayMs(Number(e.target.value))}>
              <option value={1000}>1.000 ms (1s - Respuesta Normal)</option>
              <option value={3000}>3.000 ms (3s - Latencia Aceptable)</option>
              <option value={6000}>6.000 ms (6s - Provoca 504 Timeout!)</option>
              <option value={10000}>10.000 ms (10s - Provoca 504 Timeout!)</option>
            </select>
          </div>
          <button className="warning" onClick={onTestDelay} style={{ marginTop: 'auto' }}>
            ⌛ Probar Demora ({delayMs} ms)
          </button>
        </div>

        {/* Estrés de Recursos y Resiliencia ante Fallos */}
        <div className="card">
          <div className="card-title">
            <span>💥 Caos, Estrés y Tolerancia a Fallos</span>
          </div>
          <p className="card-desc">
            Simula degradación de recursos o fallas de salud en la réplica activa para verificar la protección del kernel y el failover:
          </p>
          <div className="chaos-actions-grid">
            <button className="danger chaos-action-btn" onClick={onTriggerCpuStress} title="Ejecuta cálculos continuos saturando el hilo de CPU">
              <span>🔥 Estrés CPU</span>
              <span className="btn-caption">{stressDuration}ms de cómputo</span>
            </button>
            <button className="danger chaos-action-btn" onClick={onTriggerMemoryStress} title="Asigna buffers continuos en RAM hasta forzar OOM">
              <span>💾 Fugar {memoryMB}MB</span>
              <span className="btn-caption">Prueba límite de 128MB</span>
            </button>
            <button className="chaos-action-btn" onClick={onClearMemory} title="Libera los arreglos de memoria retenidos en el backend">
              <span>🧹 Liberar RAM</span>
              <span className="btn-caption">Vaciar buffers retenidos</span>
            </button>
            <button className="warning chaos-action-btn" onClick={onToggleHealth} title="Cambia el estado de salud del nodo entre UP y DOWN">
              <span>🩺 Conmutar Salud</span>
              <span className="btn-caption">Simular failover (UP/DOWN)</span>
            </button>
          </div>
          <p style={{ fontSize: '0.73rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>
            💡 Superar el límite del contenedor configurado en ChaosNet Lab dispara una señal <strong>OOM Kill</strong> del kernel, reiniciando la réplica.
          </p>
        </div>
      </div>

      {/* Terminal de Registro en Tiempo Real */}
      <div className="card" style={{ marginTop: '1.5rem' }}>
        <div className="card-title">
          <span>📜 Registro de Peticiones y Gateway en Vivo</span>
          <span className="mono" style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Últimos {logs.length} eventos</span>
        </div>
        <div className="log-terminal mono">
          {logs.length === 0 ? (
            <div style={{ color: 'var(--text-muted)', padding: '1rem', textAlign: 'center' }}>
              Esperando eventos del cluster... Envía peticiones desde el tablero o las herramientas de caos.
            </div>
          ) : (
            logs.map((log) => {
              let statusClass = 'status-200';
              if (log.status >= 500) statusClass = log.status === 504 ? 'status-504' : 'status-502';
              else if (log.status >= 400 || log.status === 0) statusClass = 'status-500';

              return (
                <div key={log.id} className="log-entry">
                  <span style={{ color: 'var(--text-muted)' }}>[{log.timestamp}]</span>
                  <span className={`status-tag ${statusClass}`}>{log.status || 'ERR'}</span>
                  <span style={{ color: 'var(--accent-cyan)' }}>{log.method}</span>
                  <span style={{ color: 'var(--text-main)' }}>{log.url}</span>
                  <span style={{ color: 'var(--accent-purple)' }}>({log.instance})</span>
                  <span style={{ color: 'var(--accent-amber)', marginLeft: 'auto' }}>{log.latency}ms</span>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}

