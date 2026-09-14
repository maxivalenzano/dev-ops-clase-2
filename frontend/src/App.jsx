import React, { useState, useEffect } from 'react';
import TaskBoard from './components/TaskBoard';
import ChaosLab from './components/ChaosLab';

export default function App() {
  const [activeTab, setActiveTab] = useState('board');
  const [serverInfo, setServerInfo] = useState(null);
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

  useEffect(() => {
    fetchServerInfo();
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

  return (
    <div className="container">
      {/* Header */}
      <header className="header">
        <div>
          <h1>
            <span>🚀</span> Podman Multi-Tier Lab
            <span style={{
              marginLeft: '0.75rem',
              fontSize: '0.75rem',
              padding: '0.2rem 0.55rem',
              borderRadius: '9999px',
              backgroundColor: 'rgba(56, 189, 248, 0.15)',
              border: '1px solid rgba(56, 189, 248, 0.4)',
              color: 'var(--accent-blue, #38bdf8)',
              fontWeight: 600,
              verticalAlign: 'middle'
            }}>
              v{import.meta.env.VITE_APP_VERSION || '2.0.0'}
            </span>
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            React 18 + .NET Minimal API + Redis + Nginx Reverse Proxy
          </p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          {serverInfo ? (
            <span style={{ color: 'var(--accent-green)', display: 'inline-flex', alignItems: 'center', gap: '0.4rem', fontWeight: 600, fontSize: '0.85rem' }}>
              ● Conectado: <strong className="mono">{serverInfo.instance || 'OK'}</strong>
            </span>
          ) : (
            <span style={{ color: 'var(--accent-rose)', display: 'inline-flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.85rem' }}>
              ○ Sin conexión
            </span>
          )}
          <button onClick={fetchServerInfo}>🔄 Refresh Node Info</button>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="tabs-nav">
        <button
          className={`tab-button ${activeTab === 'board' ? 'active' : ''}`}
          onClick={() => setActiveTab('board')}
        >
          <span>📋</span> Tablero Distribuido
        </button>
        <button
          className={`tab-button ${activeTab === 'chaos' ? 'active' : ''}`}
          onClick={() => setActiveTab('chaos')}
        >
          <span>⚡</span> Laboratorio de Caos y Métricas
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
