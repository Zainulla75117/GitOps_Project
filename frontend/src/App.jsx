import { useEffect, useState } from 'react'

const API_URL = import.meta.env.VITE_API_URL || ''

const styles = {
  app: {
    fontFamily: "'Segoe UI', sans-serif",
    minHeight: '100vh',
    background: '#0f172a',
    color: '#e2e8f0',
    padding: '2rem',
  },
  header: {
    textAlign: 'center',
    marginBottom: '2.5rem',
  },
  title: {
    fontSize: '2rem',
    fontWeight: 700,
    color: '#38bdf8',
    margin: 0,
  },
  subtitle: {
    color: '#94a3b8',
    marginTop: '0.5rem',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))',
    gap: '1rem',
    maxWidth: '900px',
    margin: '0 auto',
  },
  card: {
    background: '#1e293b',
    borderRadius: '0.75rem',
    padding: '1.25rem',
    border: '1px solid #334155',
  },
  cardName: {
    fontWeight: 600,
    fontSize: '1rem',
    marginBottom: '0.5rem',
  },
  badge: (status) => ({
    display: 'inline-block',
    padding: '0.2rem 0.7rem',
    borderRadius: '999px',
    fontSize: '0.75rem',
    fontWeight: 600,
    background:
      status === 'running' || status === 'synced' || status === 'active'
        ? '#166534'
        : '#7c3aed',
    color:
      status === 'running' || status === 'synced' || status === 'active'
        ? '#bbf7d0'
        : '#ede9fe',
  }),
  error: {
    textAlign: 'center',
    color: '#f87171',
    marginTop: '2rem',
  },
  loading: {
    textAlign: 'center',
    color: '#94a3b8',
    marginTop: '2rem',
  },
}

export default function App() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetch(`${API_URL}/api/items`)
      .then((r) => r.json())
      .then((data) => {
        setItems(data.items)
        setLoading(false)
      })
      .catch(() => {
        setError('Could not connect to backend API.')
        setLoading(false)
      })
  }, [])

  return (
    <div style={styles.app}>
      <div style={styles.header}>
        <h1 style={styles.title}>GitOps Demo</h1>
        <p style={styles.subtitle}>FastAPI + React on EKS via ArgoCD</p>
      </div>

      {loading && <p style={styles.loading}>Loading...</p>}
      {error && <p style={styles.error}>{error}</p>}

      {!loading && !error && (
        <div style={styles.grid}>
          {items.map((item) => (
            <div key={item.id} style={styles.card}>
              <div style={styles.cardName}>{item.name}</div>
              <span style={styles.badge(item.status)}>{item.status}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
