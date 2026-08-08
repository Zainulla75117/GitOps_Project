import { useEffect, useState, useCallback } from 'react'

const API_URL = import.meta.env.VITE_API_URL || ''

export default function App() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [isRefreshing, setIsRefreshing] = useState(false)

  const fetchData = useCallback(async (isRefresh = false) => {
    if (isRefresh) setIsRefreshing(true)
    else setLoading(true)

    try {
      const response = await fetch(`${API_URL}/api/items`)
      if (!response.ok) throw new Error('Network response was not ok')
      const data = await response.json()
      setItems(data.items)
      setError(null)
    } catch (err) {
      setError('Could not connect to backend API.')
    } finally {
      setLoading(false)
      setIsRefreshing(false)
    }
  }, [])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const getBadgeClass = (status) => {
    return status === 'running' || status === 'synced' || status === 'active'
      ? 'badge success'
      : 'badge default'
  }

  return (
    <div className="app-container">
      <header className="header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1 className="title">GitOps Deployment Status</h1>
          <p className="subtitle">
            Real-time overview of the EKS cluster resources managed by ArgoCD. (Live Demo)
          </p>
        </div>
        <button 
          className="btn" 
          onClick={() => fetchData(true)}
          disabled={loading || isRefreshing}
        >
          <svg 
            className={isRefreshing ? "animate-spin" : ""} 
            width="16" 
            height="16" 
            viewBox="0 0 24 24" 
            fill="none" 
            stroke="currentColor" 
            strokeWidth="2" 
            strokeLinecap="round" 
            strokeLinejoin="round"
          >
            <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
            <path d="M3 3v5h5" />
          </svg>
          Refresh
        </button>
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
            <div key={item.id} className="card animate-fade-in">
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
