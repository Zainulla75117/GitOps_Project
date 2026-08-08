import { useEffect, useState } from 'react'

const API_URL = import.meta.env.VITE_API_URL || ''

export default function App() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetch(`${API_URL}/api/items`)
      .then((r) => {
        if (!r.ok) throw new Error('Network response was not ok')
        return r.json()
      })
      .then((data) => {
        setItems(data.items)
        setLoading(false)
      })
      .catch(() => {
        setError('Could not connect to backend API.')
        setLoading(false)
      })
  }, [])

  const getBadgeClass = (status) => {
    return status === 'running' || status === 'synced' || status === 'active'
      ? 'badge success'
      : 'badge default'
  }

  return (
    <div className="app-container">
      <header className="header">
        <h1 className="title">GitOps Deployment Status 🚀</h1>
        <p className="subtitle">
          Real-time overview of the EKS cluster resources managed by ArgoCD. (Live Demo)
        </p>
      </header>

      {loading && (
        <div className="status-message">
          <p>Connecting to backend services...</p>
        </div>
      )}

      {error && (
        <div className="status-error">
          <p>{error}</p>
        </div>
      )}

      {!loading && !error && (
        <main className="grid">
          {items.map((item) => (
            <div key={item.id} className="card">
              <div className="card-header">
                <span className="card-name">{item.name}</span>
                <span className={getBadgeClass(item.status)}>
                  {item.status}
                </span>
              </div>
              <div style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
                Resource ID: {item.id}
              </div>
            </div>
          ))}
        </main>
      )}
    </div>
  )
}
