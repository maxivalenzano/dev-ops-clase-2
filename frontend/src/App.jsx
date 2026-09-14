import React, { useState, useEffect } from 'react';
import TaskBoard from './components/TaskBoard';
import ChaosLab from './components/ChaosLab';

export default function App() {
  const [activeTab, setActiveTab] = useState('board');
  const [serverInfo, setServerInfo] = useState(null);
  const [frontendInfo, setFrontendInfo] = useState(null);
  const [logs, setLogs] = useState([]);
  const [isRunningLoad, setIsRunningLoad] = useState(false);
  const [batchCount, setBatchCount] = useState(20);
  const [concurrency, setConcurrency] = useState(5);
  const [delayMs, setDelayMs] = useState(4000);
  const [stressDuration, setStressDuration] = useState(3000);
  const [memoryMB, setMemoryMB] = useState(50);
  const [instanceCounts, setInstanceCounts] = useState({});
  const [stats, setStats] = useState({ total: 0, success: 0, errors: 0, avgLatency: 0 });

  const addLog = (entry) => {
    setLogs((prev) => [
      { id: Date.now() + Math.random(), timestamp: new Date().toLocaleTimeString(), ...entry },
      ...prev.slice(0, 99)
    ]);
  };

  const fetchServerInfo = async () => {
    try {
      const res = await fetch('/api/info');
      const data = await res.json();
      setServerInfo(data);
      addLog({ method: 'GET', url: '/api/info', status: res.status, instance: data.instance, latency: 0 });
    } catch (err) {
      addLog({ method: 'GET', url: '/api/info', status: 502, instance: 'Unknown', error: err.message });
    }
  };

  const fetchFrontendInfo = async () => {
    try {
      const res = await fetch('/frontend-info');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setFrontendInfo(data);
      return data;
    } catch (err) {
      setFrontendInfo({ instance: 'Desconocido', status: 'DOWN', tier: 'frontend' });
      return null;
    }
  };

  useEffect(() => {
    fetchServerInfo();
    fetchFrontendInfo();
  }, []);

  const sendSingleRequest = async (url, options = {}) => {
    const start = performance.now();
    try {
      const res = await fetch(url, options);
      const latency = Math.round(performance.now() - start);
      let data = {};
      try {
        data = await res.json();
      } catch (e) {
        data = { text: await res.text() };
      }

      const instance = data.instance || (res.status >= 500 ? 'Nginx Gateway' : 'Unknown');

      // Track distribution
      setInstanceCounts((prev) => ({
        ...prev,
        [instance]: (prev[instance] || 0) + 1
      }));

      // Track stats
      setStats((prev) => {
        const total = prev.total + 1;
        const success = res.ok ? prev.success + 1 : prev.success;
        const errors = !res.ok ? prev.errors + 1 : prev.errors;
        const avgLatency = Math.round((prev.avgLatency * prev.total + latency) / total);
        return { total, success, errors, avgLatency };
      });

      addLog({
        method: options.method || 'GET',
        url,
        status: res.status,
        instance,
        latency,
        data
      });

      return { ok: res.ok, status: res.status, latency };
    } catch (err) {
      const latency = Math.round(performance.now() - start);
      setStats((prev) => ({
        ...prev,
        total: prev.total + 1,
        errors: prev.errors + 1
      }));

      addLog({
        method: options.method || 'GET',
        url,
        status: 0,
        instance: 'Network Error',
        latency,
        error: err.message
      });

      return { ok: false, status: 0, latency };
    }
  };

  const handleRunLoadTest = async () => {
    setIsRunningLoad(true);
    let completed = 0;
    const total = batchCount;

    const worker = async () => {
      while (completed < total) {
        completed++;
        await sendSingleRequest('/api/info');
      }
    };

    const workers = Array.from({ length: Math.min(concurrency, total) }, () => worker());
    await Promise.all(workers);
    setIsRunningLoad(false);
    fetchServerInfo();
    fetchFrontendInfo();
  };

  const handleTestDelay = () => {
    sendSingleRequest(`/api/delay?ms=${delayMs}`);
  };

  const handleTriggerCpuStress = () => {
    sendSingleRequest('/api/stress/cpu', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ duration: stressDuration })
    });
  };

  const handleTriggerMemoryStress = () => {
    sendSingleRequest('/api/stress/memory', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ mb: memoryMB })
    });
  };

  const handleClearMemory = () => {
    sendSingleRequest('/api/stress/memory/clear', { method: 'POST' });
  };

  const handleToggleHealth = () => {
    sendSingleRequest('/api/health/toggle', { method: 'POST' });
  };

  const handleResetStats = () => {
    setStats({ total: 0, success: 0, errors: 0, avgLatency: 0 });
    setInstanceCounts({});
    setLogs([]);
  };

  const [isRefreshing, setIsRefreshing] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(false);

  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(() => {
      fetchServerInfo();
      fetchFrontendInfo();
    }, 4000);
    return () => clearInterval(interval);
  }, [autoRefresh]);

  const handleRefreshNodes = async () => {
    setIsRefreshing(true);
    await Promise.all([fetchServerInfo(), fetchFrontendInfo()]);
    setTimeout(() => setIsRefreshing(false), 400);
  };

  return (
    <div className="container">
      {/* Encabezado Principal */}
      <header className="header">
        <div className="header-brand">
          <div className="header-title-row">
            <h1>
              <span>🚀</span> ChaosNet • Panel de Control
            </h1>
            <span className="header-version">
              v{import.meta.env.VITE_APP_VERSION || '2.0.0'}
            </span>
          </div>

          <div className="header-arch-bar">
            <span className="arch-pill" style={{ color: 'var(--accent-blue)', borderColor: 'rgba(59, 130, 246, 0.35)', fontWeight: 600 }} title="Plataforma ChaosNet Lab">
              ⚡ ChaosNet Lab
            </span>
            <span className="arch-sep">|</span>
            <span className="arch-pill" title="Puerta de enlace Nginx con balanceo y timeouts configurados">
              🌐 Nginx Gateway (Port 80/8080)
            </span>
            <span className="arch-sep">➔</span>
            <span className="arch-pill" title="Contenedores estáticos de Vite/React en alta disponibilidad">
              ⚛️ SPA React Cluster
            </span>
            <span className="arch-sep">➔</span>
            <span className="arch-pill" title="Réplicas de microservicio .NET 10 Minimal API">
              ⚙️ API .NET Replicas
            </span>
            <span className="arch-sep">➔</span>
            <span className="arch-pill" title="Almacén en memoria persistente y centralizado">
              ⚡ Redis Cache
            </span>
          </div>
        </div>

        <div className="header-actions">
          {/* Badge del Nodo Frontend */}
          <div className="header-node-badge ui-node" title="Instancia de contenedor que sirve los assets estáticos del frontend">
            <span>🖥️ UI:</span>
            <strong className="mono">{frontendInfo?.instance || 'Cargando...'}</strong>
          </div>

          {/* Badge del Nodo Backend */}
          {serverInfo ? (
            <div className="header-node-badge api-node-up" title="Instancia de backend que atendió la última solicitud">
              <span className="pulse-dot" style={{ backgroundColor: 'var(--accent-green)' }} />
              <span>API:</span>
              <strong className="mono">{serverInfo.instance || 'OK'}</strong>
            </div>
          ) : (
            <div className="header-node-badge api-node-down" title="Sin respuesta del servicio backend">
              <span className="pulse-dot" style={{ backgroundColor: 'var(--accent-rose)' }} />
              <span>API: Desconectada</span>
            </div>
          )}

          {/* Toggle de Monitoreo en Vivo */}
          <button
            className={`header-refresh-btn ${autoRefresh ? 'success' : ''}`}
            onClick={() => setAutoRefresh(!autoRefresh)}
            title={autoRefresh ? 'Desactivar consulta periódica automática' : 'Activar consulta automática cada 4 segundos'}
          >
            {autoRefresh ? '🟢 En Vivo (4s)' : '⏸️ Polling'}
          </button>

          {/* Botón de Refresco Manual */}
          <button
            className="header-refresh-btn"
            onClick={handleRefreshNodes}
            disabled={isRefreshing}
            title="Actualizar estado de réplicas y firmas de nodo"
          >
            <span className={isRefreshing ? 'refresh-spinning' : ''}>🔄</span>
            <span>{isRefreshing ? 'Consultando...' : 'Actualizar'}</span>
          </button>
        </div>
      </header>

      {/* Navegación por Pestañas */}
      <nav className="tabs-nav">
        <button
          className={`tab-button ${activeTab === 'board' ? 'active' : ''}`}
          onClick={() => setActiveTab('board')}
          title="Gestión de tareas sincronizadas en Redis con firma de nodo"
        >
          <span>📋</span>
          <div style={{ textAlign: 'left' }}>
            <div>Tablero Distribuido</div>
            <span className="tab-sub">Persistencia & Balanceo Redis</span>
          </div>
        </button>
        <button
          className={`tab-button ${activeTab === 'chaos' ? 'active' : ''}`}
          onClick={() => setActiveTab('chaos')}
          title="Pruebas de estrés, resiliencia, latencia y balanceo upstream"
        >
          <span>⚡</span>
          <div style={{ textAlign: 'left' }}>
            <div>Laboratorio de Caos y Métricas</div>
            <span className="tab-sub">Resiliencia, OOM & Carga</span>
          </div>
        </button>
      </nav>

      {/* Main Tab Views */}
      <main className="tab-content">
        {activeTab === 'board' ? (
          <TaskBoard onLogEvent={addLog} />
        ) : (
          <ChaosLab
            serverInfo={serverInfo}
            instanceCounts={instanceCounts}
            stats={stats}
            logs={logs}
            onResetStats={handleResetStats}
            isRunningLoad={isRunningLoad}
            batchCount={batchCount}
            setBatchCount={setBatchCount}
            concurrency={concurrency}
            setConcurrency={setConcurrency}
            onRunLoadTest={handleRunLoadTest}
            delayMs={delayMs}
            setDelayMs={setDelayMs}
            onTestDelay={handleTestDelay}
            stressDuration={stressDuration}
            onTriggerCpuStress={handleTriggerCpuStress}
            memoryMB={memoryMB}
            onTriggerMemoryStress={handleTriggerMemoryStress}
            onClearMemory={handleClearMemory}
            onToggleHealth={handleToggleHealth}
          />
        )}
      </main>
    </div>
  );
}
