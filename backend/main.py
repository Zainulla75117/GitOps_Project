from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="GitOps Demo API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"service": "gitops-backend", "version": "1.0.0", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/api/items")
def get_items():
    return {
        "items": [
            {"id": 1, "name": "EKS Cluster", "status": "running"},
            {"id": 2, "name": "ArgoCD", "status": "synced"},
            {"id": 3, "name": "GitHub Actions", "status": "active"},
        ]
    }
