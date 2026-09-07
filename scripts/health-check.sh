#!/bin/bash
# ClipFarm Health Check
# Sollte regelmäßig via Cron laufen

set -e

ALERT_WEBHOOK="${TELEGRAM_WEBHOOK:-}"

services=(
  "clipfarm_supoclip:SupoClip"
  "clipfarm_postgres:PostgreSQL"
  "clipfarm_redis:Redis"
  "clipfarm_minio:MinIO"
  "clipfarm_n8n:n8n"
  "clipfarm_dashboard:Dashboard"
)

failed=()

for service in "${services[@]}"; do
  container_name=$(echo "$service" | cut -d: -f1)
  service_name=$(echo "$service" | cut -d: -f2)
  
  if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    failed+=("$service_name")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  message="🚨 ClipFarm Alert: ${failed[*]} nicht erreichbar!"
  echo "$message"
  
  if [ -n "$ALERT_WEBHOOK" ]; then
    curl -s -X POST "$ALERT_WEBHOOK" -d "text=$message" || true
  fi
  
  exit 1
fi

# Disk-Check
disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$disk_usage" -gt 90 ]; then
  message="⚠️ ClipFarm Warnung: Disk usage bei ${disk_usage}%!"
  echo "$message"
  
  if [ -n "$ALERT_WEBHOOK" ]; then
    curl -s -X POST "$ALERT_WEBHOOK" -d "text=$message" || true
  fi
fi

echo "✅ Alle Services laufen. Disk: ${disk_usage}%"
