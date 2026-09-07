# ClipFarm – Deploy-Repo (öffentlich)

Öffentlicher Spiegel von `jonas-hostmann/clipfarm` (privat) für das Coolify-Deployment
auf https://coolify.hostmann-media.de.

## Stack (docker-compose.yml)

| Service | Subdomain | Port |
|---------|-----------|------|
| SupoClip | clipfarm.hostmann-media.de | 3000 |
| Dashboard | dashboard.clipfarm.hostmann-media.de | 8080 |
| n8n | n8n.clipfarm.hostmann-media.de | 5678 |
| MinIO Console | storage.clipfarm.hostmann-media.de | 9001 |
| PostgreSQL / Redis / Ollama | intern | – |

## Enthaltene Ordner

- `config/` – Quellen (YouTube/Twitch) + PostgreSQL-Schema (wird automatisch initialisiert)
- `dashboard/` – FastAPI Monitoring-Dashboard (Build per Dockerfile)
- `n8n/workflows/` – 4 Workflows: Content Discovery, Clip Processing, Export für Mac Mini, Upload Queue
- `scripts/` – Setup- und Health-Check-Skripte

## Setup nach Deployment

1. Env Vars in Coolify setzen (siehe `.env.example`)
2. Domains in Coolify zuweisen (Tabelle oben)
3. n8n öffnen → Workflows aus `n8n/workflows/` importieren → Postgres-Credentials anlegen
4. MinIO Buckets anlegen: `clipfarm-raw`, `clipfarm-clips`, `clipfarm-exports`
