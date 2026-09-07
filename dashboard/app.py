#!/usr/bin/env python3
"""
ClipFarm Dashboard – VPS Monitoring & Übersicht
Fokus: Downloads, KI-Verarbeitung, Clip-Status
OpenRouter-Integration: Key & Modell im Dashboard konfigurierbar.
"""

import os
import json
import re
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

import httpx
import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, Request, Form
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import JSONResponse, RedirectResponse
from uvicorn import run

app = FastAPI(title="ClipFarm Dashboard")
templates = Jinja2Templates(directory="templates")

DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres:5432/supoclip")
COOLIFY_URL = os.getenv("COOLIFY_URL", "https://coolify.hostmann-media.de")
COOLIFY_TOKEN = os.getenv("COOLIFY_TOKEN", "")
SUPOCLIP_APP_UUID = os.getenv("SUPOCLIP_APP_UUID", "")

# OpenRouter Modelle (kann später dynamisch geladen werden)
OPENROUTER_MODELS = [
    ("anthropic/claude-3.5-sonnet", "Claude 3.5 Sonnet (empfohlen)"),
    ("anthropic/claude-3-opus", "Claude 3 Opus"),
    ("openai/gpt-4o", "GPT-4o"),
    ("openai/gpt-4o-mini", "GPT-4o Mini"),
    ("google/gemini-1.5-pro", "Gemini 1.5 Pro"),
    ("google/gemini-1.5-flash", "Gemini 1.5 Flash"),
    ("meta-llama/llama-3.1-70b-instruct", "Llama 3.1 70B"),
    ("mistralai/mistral-large", "Mistral Large"),
]


def get_db():
    return psycopg2.connect(DB_URL, cursor_factory=RealDictCursor)


def get_setting(key: str, default: str = "") -> str:
    """Liest ein Setting aus der DB"""
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT value FROM settings WHERE key = %s", (key,))
    row = cursor.fetchone()
    db.close()
    return row['value'] if row else default


def set_setting(key: str, value: str) -> bool:
    """Schreibt ein Setting in die DB"""
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO settings (key, value, updated_at) VALUES (%s, %s, NOW())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
    """, (key, value))
    db.commit()
    db.close()
    return True


# ═══════════════════════════════════════════════
# DASHBOARD (Hauptseite)
# ═══════════════════════════════════════════════

@app.get("/")
async def dashboard(request: Request):
    db = get_db()
    cursor = db.cursor()
    
    cursor.execute("SELECT COUNT(*) as count FROM videos WHERE DATE(downloaded_at) = CURRENT_DATE")
    videos_today = cursor.fetchone()['count'] or 0
    
    cursor.execute("SELECT COUNT(*) as count FROM clips WHERE DATE(created_at) = CURRENT_DATE")
    clips_today = cursor.fetchone()['count'] or 0
    
    cursor.execute("SELECT COUNT(*) as count FROM clips WHERE status = 'ready' AND exported = false")
    pending_export = cursor.fetchone()['count'] or 0
    
    cursor.execute("SELECT COUNT(*) as count FROM videos")
    total_videos = cursor.fetchone()['count'] or 0
    
    cursor.execute("SELECT COUNT(*) as count FROM clips")
    total_clips = cursor.fetchone()['count'] or 0
    
    cursor.execute("SELECT COUNT(*) as count FROM clips WHERE exported = true")
    total_exported = cursor.fetchone()['count'] or 0
    
    cursor.execute("""
        SELECT DATE(downloaded_at) as date, COUNT(*) as videos,
            SUM((SELECT COUNT(*) FROM clips c WHERE c.source_video_id = v.id)) as clips
        FROM videos v
        WHERE downloaded_at > CURRENT_DATE - INTERVAL '7 days'
        GROUP BY DATE(downloaded_at) ORDER BY date
    """)
    weekly_data = cursor.fetchall()
    
    cursor.execute("""
        SELECT job_id, video_id, status, progress, started_at, message
        FROM jobs WHERE status IN ('running', 'queued') ORDER BY started_at DESC LIMIT 10
    """)
    active_jobs = cursor.fetchall()
    
    cursor.execute("""
        SELECT c.id, c.title, c.virality_score, c.duration, c.status, c.exported,
               v.title as source_title, c.created_at
        FROM clips c JOIN videos v ON c.source_video_id = v.id
        ORDER BY c.created_at DESC LIMIT 10
    """)
    recent_clips = cursor.fetchall()
    
    cursor.execute("""
        SELECT c.id, c.title, c.virality_score, c.duration, v.title as source_title, c.created_at
        FROM clips c JOIN videos v ON c.source_video_id = v.id
        WHERE c.status = 'ready' ORDER BY c.virality_score DESC NULLS LAST LIMIT 10
    """)
    top_performers = cursor.fetchall()
    
    cursor.execute("""
        SELECT COUNT(*) as total_clips, SUM(duration) as total_duration, AVG(virality_score) as avg_score
        FROM clips WHERE status = 'ready'
    """)
    storage_stats = cursor.fetchone()
    
    db.close()
    
    chart_labels = [str(d['date']) for d in weekly_data]
    chart_videos = [d['videos'] for d in weekly_data]
    chart_clips = [d['clips'] or 0 for d in weekly_data]
    
    return templates.TemplateResponse("index.html", {
        "request": request,
        "metrics": {
            "videos_today": videos_today, "clips_today": clips_today,
            "pending_export": pending_export, "total_videos": total_videos,
            "total_clips": total_clips, "total_exported": total_exported,
        },
        "chart": {
            "labels": json.dumps(chart_labels),
            "videos": json.dumps(chart_videos),
            "clips": json.dumps(chart_clips),
        },
        "active_jobs": active_jobs,
        "recent_clips": recent_clips,
        "top_performers": top_performers,
        "storage_stats": storage_stats,
        "now": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    })


# ═══════════════════════════════════════════════
# SETTINGS (OpenRouter Konfiguration)
# ═══════════════════════════════════════════════

@app.get("/settings")
async def settings_page(request: Request):
    """Settings-Seite für OpenRouter & LLM-Konfiguration"""
    settings = {
        'openrouter_api_key': get_setting('openrouter_api_key'),
        'openrouter_model': get_setting('openrouter_model', 'anthropic/claude-3.5-sonnet'),
        'llm_provider': get_setting('llm_provider', 'openrouter'),
        'assembly_ai_key': get_setting('assembly_ai_key'),
    }
    
    # Key maskieren für Anzeige
    key_display = settings['openrouter_api_key']
    if len(key_display) > 8:
        key_display = key_display[:4] + "..." + key_display[-4:]
    
    return templates.TemplateResponse("settings.html", {
        "request": request,
        "settings": settings,
        "key_display": key_display,
        "models": OPENROUTER_MODELS,
        "coolify_connected": bool(COOLIFY_TOKEN and SUPOCLIP_APP_UUID),
        "now": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    })


@app.post("/settings/save")
async def settings_save(
    openrouter_api_key: str = Form(""),
    openrouter_model: str = Form("anthropic/claude-3.5-sonnet"),
    llm_provider: str = Form("openrouter"),
    assembly_ai_key: str = Form(""),
):
    """Speichert Settings in DB und aktualisiert Coolify Env Vars"""
    
    # In DB speichern
    set_setting('openrouter_api_key', openrouter_api_key)
    set_setting('openrouter_model', openrouter_model)
    set_setting('llm_provider', llm_provider)
    set_setting('assembly_ai_key', assembly_ai_key)
    
    # SupoClip LLM-Format für OpenRouter
    # OpenRouter nutzt OpenAI-kompatible API
    supoclip_llm = f"openai:{openrouter_model}"
    set_setting('supoclip_llm_config', supoclip_llm)
    
    # Coolify Env Vars aktualisieren (falls konfiguriert)
    coolify_result = await _update_coolify_envs(openrouter_api_key, supoclip_llm, assembly_ai_key)
    
    return JSONResponse({
        "success": True,
        "message": "Settings gespeichert!" + (" SupoClip wird neu gestartet..." if coolify_result else ""),
        "coolify_updated": coolify_result,
    })


async def _update_coolify_envs(api_key: str, llm: str, assembly_key: str) -> bool:
    """Aktualisiert Coolify Env Vars und restartet SupoClip"""
    if not COOLIFY_TOKEN or not SUPOCLIP_APP_UUID:
        return False
    
    headers = {
        "Authorization": f"Bearer {COOLIFY_TOKEN}",
        "Content-Type": "application/json",
    }
    
    try:
        async with httpx.AsyncClient() as client:
            # 1. Env Vars setzen
            envs_payload = {
                "envs": [
                    {
                        "key": "GOOGLE_API_KEY",
                        "value": "",
                        "is_preview": False,
                        "is_build_time": True,
                        "is_literal": True,
                    },
                    {
                        "key": "OPENAI_API_KEY",
                        "value": api_key,
                        "is_preview": False,
                        "is_build_time": True,
                        "is_literal": True,
                    },
                    {
                        "key": "OPENAI_BASE_URL",
                        "value": "https://openrouter.ai/api/v1",
                        "is_preview": False,
                        "is_build_time": True,
                        "is_literal": True,
                    },
                    {
                        "key": "LLM",
                        "value": llm,
                        "is_preview": False,
                        "is_build_time": True,
                        "is_literal": True,
                    },
                    {
                        "key": "ASSEMBLY_AI_API_KEY",
                        "value": assembly_key,
                        "is_preview": False,
                        "is_build_time": True,
                        "is_literal": True,
                    },
                ]
            }
            
            resp = await client.patch(
                f"{COOLIFY_URL}/api/v1/applications/{SUPOCLIP_APP_UUID}/envs",
                headers=headers,
                json=envs_payload,
                timeout=30.0,
            )
            
            if resp.status_code not in (200, 201):
                print(f"Coolify env update failed: {resp.status_code} {resp.text}")
                return False
            
            # 2. Restart triggern
            resp2 = await client.get(
                f"{COOLIFY_URL}/api/v1/applications/{SUPOCLIP_APP_UUID}/restart",
                headers=headers,
                timeout=30.0,
            )
            
            return resp2.status_code in (200, 201)
            
    except Exception as e:
        print(f"Coolify update error: {e}")
        return False


@app.get("/api/settings")
async def api_settings():
    """JSON-API: Aktuelle Settings"""
    return {
        "openrouter_api_key_set": bool(get_setting('openrouter_api_key')),
        "openrouter_model": get_setting('openrouter_model', 'anthropic/claude-3.5-sonnet'),
        "llm_provider": get_setting('llm_provider', 'openrouter'),
        "assembly_ai_key_set": bool(get_setting('assembly_ai_key')),
    }


# ═══════════════════════════════════════════════
# API ENDPOINTS
# ═══════════════════════════════════════════════

@app.get("/api/status")
async def api_status():
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT COUNT(*) as count FROM videos WHERE DATE(downloaded_at) = CURRENT_DATE")
    videos_today = cursor.fetchone()['count']
    cursor.execute("SELECT COUNT(*) as count FROM clips WHERE DATE(created_at) = CURRENT_DATE")
    clips_today = cursor.fetchone()['count']
    cursor.execute("SELECT COUNT(*) as count FROM clips WHERE status = 'ready' AND exported = false")
    pending_export = cursor.fetchone()['count']
    db.close()
    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "today": {"videos": videos_today, "clips": clips_today, "pending_export": pending_export}
    }


@app.get("/api/clip/{clip_id}")
async def clip_detail(clip_id: str):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT c.*, v.title as source_title, v.url as source_url FROM clips c JOIN videos v ON c.source_video_id = v.id WHERE c.id = %s", (clip_id,))
    clip = cursor.fetchone()
    db.close()
    if not clip:
        return {"error": "Clip not found"}
    return dict(clip)


@app.get("/api/export-queue")
async def export_queue():
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT c.id, c.title, c.virality_score, c.duration, c.file_path, c.thumbnail_path, v.title as source_title
        FROM clips c JOIN videos v ON c.source_video_id = v.id
        WHERE c.status = 'ready' AND c.exported = false ORDER BY c.virality_score DESC LIMIT 50
    """)
    clips = cursor.fetchall()
    db.close()
    return {"count": len(clips), "clips": [dict(c) for c in clips]}


if __name__ == "__main__":
    run(app, host="0.0.0.0", port=8080)
