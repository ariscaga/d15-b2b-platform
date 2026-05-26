function App() {
  const appEnv = import.meta.env.VITE_APP_ENV || 'unknown'
  const appName = import.meta.env.VITE_APP_NAME || 'D15'
  const supabaseConnected = import.meta.env.VITE_SUPABASE_URL ? '✅ connected' : '❌ missing'

  const envColors: Record<string, string> = {
    production: '#10b981',
    demo: '#3b82f6',
    sandbox: '#f59e0b',
    unknown: '#ef4444',
  }

  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui, sans-serif' }}>
      <h1>{appName}</h1>
      <div
        style={{
          display: 'inline-block',
          padding: '0.25rem 0.75rem',
          background: envColors[appEnv],
          color: 'white',
          borderRadius: '4px',
          fontSize: '0.875rem',
          fontWeight: 600,
          textTransform: 'uppercase',
        }}
      >
        {appEnv}
      </div>
      <p style={{ marginTop: '1rem' }}>
        Supabase: {supabaseConnected}
      </p>
    </div>
  )
}

export default App