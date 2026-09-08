import React, { useState, useEffect, useRef } from 'react';

export default function App() {
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
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            React 18 + .NET Minimal API + Nginx Reverse Proxy
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

      {/* Realtime Stats Bar */}
      <div className="stats-grid">
        <div className="stat-box">
          <span className="stat-label">Total Requests</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-blue)' }}>{stats.total}</span>
        </div>
        <div className="stat-box">
          <span className="stat-label">Success (2xx)</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-green)' }}>{stats.success}</span>
        </div>
        <div className="stat-box">
          <span className="stat-label">Errors (5xx/4xx)</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-rose)' }}>{stats.errors}</span>
        </div>
        <div className="stat-box">
          <span className="stat-label">Avg Latency</span>
          <span className="stat-value mono" style={{ color: 'var(--accent-amber)' }}>{stats.avgLatency} ms</span>
        </div>
      </div>

      {/* Main Grid */}
      <div className="grid">
        {/* Load Balancer Distribution */}
        <div className="card">
          <div className="card-title">
            <span>⚖️ Upstream Load Distribution</span>
            <button onClick={handleResetStats} style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}>Clear</button>
          </div>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            Nginx distributes traffic across available backend instances:
          </p>
          <div className="dist-list">
            {Object.keys(instanceCounts).length === 0 ? (
              <p className="mono" style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>No requests recorded yet.</p>
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
            <div style={{ marginTop: '0.5rem', background: 'var(--bg-card)', padding: '0.75rem', borderRadius: '0.375rem', fontSize: '0.8rem' }}>
              <div className="mono" style={{ color: 'var(--accent-cyan)', marginBottom: '0.25rem' }}>Active Target Info:</div>
              <div className="mono">Host: <strong>{serverInfo.hostname}</strong> (PID {serverInfo.pid})</div>
              <div className="mono">Port: <strong>{serverInfo.port}</strong> | Uptime: {serverInfo.uptimeSeconds}s</div>
              <div className="mono">RSS Mem: <strong>{serverInfo.memory?.rssMB} MB</strong> (Buffers: {serverInfo.memory?.totalBuffersRetainedMB} MB)</div>
            </div>
          )}
        </div>

        {/* Load Testing Controls */}
        <div className="card">
          <div className="card-title">
            <span>⚡ Concurrent Load Generator</span>
          </div>
          <div className="input-row">
            <label style={{ flex: 1 }}>Requests:</label>
            <select value={batchCount} onChange={(e) => setBatchCount(Number(e.target.value))}>
              <option value={10}>10 requests</option>
              <option value={50}>50 requests</option>
              <option value={100}>100 requests</option>
              <option value={250}>250 requests</option>
            </select>
          </div>
          <div className="input-row">
            <label style={{ flex: 1 }}>Concurrency:</label>
            <select value={concurrency} onChange={(e) => setConcurrency(Number(e.target.value))}>
              <option value={1}>1 (Sequential)</option>
              <option value={5}>5 parallel</option>
              <option value={10}>10 parallel</option>
              <option value={20}>20 parallel</option>
            </select>
          </div>
          <button className="primary" onClick={handleRunLoadTest} disabled={isRunningLoad}>
            {isRunningLoad ? '⏳ Generating Load...' : '▶ Launch Load Test'}
          </button>
        </div>

        {/* Chaos: Timeouts & Delays */}
        <div className="card">
          <div className="card-title">
            <span>⏱️ Timeout & Gateway Delay</span>
          </div>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            Nginx default timeout is configured at <strong>5 seconds</strong>. If delay exceeds 5s, Nginx returns <code>504 Gateway Timeout</code>.
          </p>
          <div className="input-row">
            <label style={{ flex: 1 }}>Delay (ms):</label>
            <select value={delayMs} onChange={(e) => setDelayMs(Number(e.target.value))}>
              <option value={1000}>1000 ms (1s - OK)</option>
              <option value={3000}>3000 ms (3s - OK)</option>
              <option value={6000}>6000 ms (6s - 504 Timeout!)</option>
              <option value={10000}>10000 ms (10s - 504 Timeout!)</option>
            </select>
          </div>
          <button className="warning" onClick={handleTestDelay}>
            ⌛ Send Delayed Request ({delayMs}ms)
          </button>
        </div>

        {/* Chaos: Resource Limits & Failover */}
        <div className="card">
          <div className="card-title">
            <span>💥 Chaos & Resource Stress</span>
          </div>
          <div className="button-group">
            <button className="danger" onClick={handleTriggerCpuStress}>
              🔥 Stress CPU ({stressDuration}ms)
            </button>
            <button className="danger" onClick={handleTriggerMemoryStress}>
              💾 Leak {memoryMB}MB RAM
            </button>
            <button onClick={handleClearMemory}>
              🧹 Free Buffers
            </button>
            <button className="warning" onClick={handleToggleHealth}>
              🩺 Toggle Health (UP/DOWN)
            </button>
          </div>
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
            Allocating beyond container limits (e.g. 128MB) causes the Linux kernel / Podman to trigger an <strong>OOM Kill</strong>.
          </p>
        </div>
      </div>

      {/* Live Request Stream Log */}
      <div className="card">
        <div className="card-title">
          <span>📜 Realtime Request & Gateway Log</span>
          <span className="mono" style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Latest 100 events</span>
        </div>
        <div className="log-terminal mono">
          {logs.map((log) => {
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
          })}
        </div>
      </div>
    </div>
  );
}
