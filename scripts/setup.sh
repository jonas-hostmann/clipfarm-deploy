#!/bin/bash
# ClipFarm Setup Script
# Einmalig nach dem ersten Deployment ausführen

set -e

echo "🎬 ClipFarm Setup"
echo "=================="

# 1. Datenbank-Schema initialisieren
echo "📦 Initialisiere Datenbank-Schema..."
docker exec -i clipfarm_postgres psql -U postgres -d supoclip < config/schema.sql

# 2. MinIO Bucket erstellen
echo "🪣 Erstelle MinIO Bucket..."
docker exec clipfarm_minio mc alias set local http://localhost:9000 admin "${MINIO_ROOT_PASSWORD}"
docker exec clipfarm_minio mc mb local/clipfarm-clips --ignore-existing || true
docker exec clipfarm_minio mc mb local/clipfarm-raw --ignore-existing || true

# 3. n8n Workflows importieren
echo "⚡ Importiere n8n Workflows..."
curl -X POST http://localhost:5678/rest/workflows \
  -H "Content-Type: application/json" \
  -d @n8n/workflows/01_content_discovery.json || echo "n8n noch nicht bereit, manuell importieren"

# 4. Health-Check
echo "🔍 Health-Check..."
curl -s http://localhost:8080/api/status | jq . || echo "Dashboard noch nicht bereit"

echo ""
echo "✅ Setup abgeschlossen!"
echo ""
echo "URLs:"
echo "  Dashboard:  http://$(hostname -I | awk '{print $1}'):8080"
echo "  SupoClip:   http://$(hostname -I | awk '{print $1}'):3000"
echo "  n8n:        http://$(hostname -I | awk '{print $1}'):5678"
echo "  MinIO:      http://$(hostname -I | awk '{print $1}'):9001"
