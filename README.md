# ClipFarm – Deploy-Repo (öffentlich)

Öffentlicher Spiegel von `jonas-hostmann/clipfarm` (privat) für das Coolify-Deployment
auf https://coolify.hostmann-media.de.

## Stack (docker-compose.yml)

| Service | Subdomain | Port |
|---------|-----------|------|
| SupoClip Frontend | clipfarm.hostmann-media.de | 3107 |
| SupoClip API | api.clipfarm.hostmann-media.de | 8000 |
| Dashboard | dashboard.clipfarm.hostmann-media.de | 8080 |
| n8n | n8n.clipfarm.hostmann-media.de | 5678 |
| PostgreSQL / Redis | intern | – |

Hinweise:
- SupoClip (Backend, Frontend, Worker) wird aus dem offiziellen Repo `FujiwaraChoki/supoclip` gebaut.
- LLM läuft über OpenRouter (OPENAI_BASE_URL + OPENAI_API_KEY in Coolify setzen).
- Ollama und MinIO sind vorerst entfernt und werden später nachgerüstet.

## Enthaltene Ordner

- `config/` – Quellen (YouTube/Twitch) + PostgreSQL-Schemas (ClipFarm + SupoClip)
- `dashboard/` – FastAPI Monitoring-Dashboard (Build per Dockerfile)
- `n8n/workflows/` – 4 Workflows: Content Discovery, Clip Processing, Export für Mac Mini, Upload Queue
- `scripts/` – Setup- und Health-Check-Skripte

## Setup nach Deployment

1. Env Vars in Coolify setzen (siehe `.env.example`), insbesondere `OPENAI_API_KEY` (OpenRouter)
2. n8n öffnen → Workflows aus `n8n/workflows/` importieren → Postgres-Credentials anlegen
