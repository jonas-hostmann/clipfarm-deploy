-- ClipFarm – Datenbank-Schema (VPS-Only)
-- PostgreSQL 16 | Upload/Publishing läuft auf separatem Mac Mini

-- Erweiterungen
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────
-- VIDEOS (Roh-Downloads)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS videos (
    id              VARCHAR(32) PRIMARY KEY,      -- YouTube Video ID
    title           TEXT NOT NULL,
    url             TEXT NOT NULL,
    description     TEXT,
    source_channel  VARCHAR(100),
    source_type     VARCHAR(20) DEFAULT 'youtube', -- youtube, twitch, etc.
    duration        INTEGER,                      -- Sekunden
    view_count      BIGINT DEFAULT 0,
    file_path       TEXT,
    thumbnail_path  TEXT,
    tags            TEXT[],
    status          VARCHAR(20) DEFAULT 'pending', -- pending, downloading, downloaded, error
    downloaded_at   TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_videos_status ON videos(status);
CREATE INDEX idx_videos_downloaded_at ON videos(downloaded_at);

-- ─────────────────────────────────────────────
-- CLIPS (Generierte Shorts)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clips (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_video_id VARCHAR(32) REFERENCES videos(id) ON DELETE CASCADE,
    title           TEXT,
    hook            TEXT,
    virality_score  INTEGER DEFAULT 0,            -- 0-100
    duration        NUMERIC(6,2),                 -- Sekunden
    start_time      NUMERIC(10,2),                -- Sekunden im Original
    end_time        NUMERIC(10,2),
    file_path       TEXT,
    thumbnail_path  TEXT,
    status          VARCHAR(20) DEFAULT 'processing', -- processing, ready, error
    exported        BOOLEAN DEFAULT FALSE,         -- true = an Mac Mini übergeben
    exported_at     TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_clips_status ON clips(status);
CREATE INDEX idx_clips_score ON clips(virality_score DESC);
CREATE INDEX idx_clips_video ON clips(source_video_id);
CREATE INDEX idx_clips_exported ON clips(exported) WHERE exported = false;

-- ─────────────────────────────────────────────
-- UPLOADS (Veröffentlichte Clips – nur Tracking)
-- Wird vom Mac Mini gefüllt, nicht vom VPS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS uploads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clip_id         UUID REFERENCES clips(id) ON DELETE CASCADE,
    platform        VARCHAR(20) NOT NULL,         -- tiktok, instagram, youtube, twitter
    account_id      VARCHAR(50),
    post_url        TEXT,
    caption         TEXT,
    hashtags        TEXT[],
    status          VARCHAR(20) DEFAULT 'pending', -- pending, uploaded, failed
    uploaded_at     TIMESTAMP,
    ip_address      INET,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_uploads_platform ON uploads(platform);
CREATE INDEX idx_uploads_date ON uploads(uploaded_at);

-- ─────────────────────────────────────────────
-- PERFORMANCE METRICS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS performance_metrics (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clip_id         UUID REFERENCES clips(id) ON DELETE CASCADE,
    platform        VARCHAR(20) NOT NULL,
    views           BIGINT DEFAULT 0,
    likes           BIGINT DEFAULT 0,
    shares          BIGINT DEFAULT 0,
    comments        BIGINT DEFAULT 0,
    checked_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_perf_clip ON performance_metrics(clip_id);
CREATE INDEX idx_perf_date ON performance_metrics(checked_at);

-- ─────────────────────────────────────────────
-- ACCOUNTS (Social Media Accounts – nur Tracking)
-- Wird vom Mac Mini gefüllt, nicht vom VPS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS accounts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    platform        VARCHAR(20) NOT NULL,
    username        VARCHAR(100) NOT NULL,
    email           VARCHAR(255),
    niche           VARCHAR(50),                  -- tech, gaming, comedy, etc.
    status          VARCHAR(20) DEFAULT 'active', -- active, suspended, banned
    last_used       TIMESTAMP,
    daily_uploads   INTEGER DEFAULT 0,
    daily_uploads_reset DATE,
    avg_views_last_7d BIGINT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(platform, username)
);

CREATE INDEX idx_accounts_platform ON accounts(platform);
CREATE INDEX idx_accounts_status ON accounts(status);

-- ─────────────────────────────────────────────
-- UPLOAD QUEUE (für Mac Mini Export)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS upload_queue (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clip_id         UUID REFERENCES clips(id) ON DELETE CASCADE,
    platform        VARCHAR(20) NOT NULL,
    scheduled_at    TIMESTAMP NOT NULL,
    executed_at     TIMESTAMP,
    status          VARCHAR(20) DEFAULT 'pending', -- pending, done, failed
    error_message   TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_queue_status ON upload_queue(status);
CREATE INDEX idx_queue_scheduled ON upload_queue(scheduled_at);

-- ─────────────────────────────────────────────
-- JOBS (Hintergrund-Verarbeitung)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS jobs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          VARCHAR(100) NOT NULL,
    video_id        VARCHAR(32) REFERENCES videos(id),
    clip_id         UUID REFERENCES clips(id),
    type            VARCHAR(50) NOT NULL,         -- download, transcribe, render
    status          VARCHAR(20) DEFAULT 'queued', -- queued, running, completed, failed
    progress        INTEGER DEFAULT 0,            -- 0-100
    message         TEXT,
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_video ON jobs(video_id);

-- ─────────────────────────────────────────────
-- STRATEGY INSIGHTS (Learning)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS strategy_insights (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    data            JSONB NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- SETTINGS (Konfiguration – OpenRouter etc.)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settings (
    key             VARCHAR(100) PRIMARY KEY,
    value           TEXT NOT NULL,
    description     TEXT,
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- Default Settings für OpenRouter
INSERT INTO settings (key, value, description) VALUES
    ('openrouter_api_key', '', 'OpenRouter API Key für LLM-Zugriff'),
    ('openrouter_model', 'anthropic/claude-3.5-sonnet', 'Verwendetes LLM-Modell über OpenRouter'),
    ('llm_provider', 'openrouter', 'LLM-Provider: openrouter, google, openai, anthropic'),
    ('supoclip_llm_config', 'openai:claude-3.5-sonnet', 'SupoClip LLM-Format'),
    ('assembly_ai_key', '', 'AssemblyAI API Key für Transkription (optional)')
ON CONFLICT (key) DO NOTHING;

-- ─────────────────────────────────────────────
-- VIEWS (Hilfsabfragen)
-- ─────────────────────────────────────────────

-- View: Tages-Statistik
CREATE OR REPLACE VIEW daily_stats AS
SELECT 
    DATE(v.created_at) as date,
    COUNT(DISTINCT v.id) FILTER (WHERE v.source_type = 'youtube') as youtube_downloads,
    COUNT(DISTINCT c.id) as clips_created,
    COUNT(DISTINCT c.id) FILTER (WHERE c.exported = true) as clips_exported
FROM videos v
FULL OUTER JOIN clips c ON DATE(v.created_at) = DATE(c.created_at)
GROUP BY DATE(v.created_at)
ORDER BY date DESC;

-- View: Beste Performer
CREATE OR REPLACE VIEW top_clips AS
SELECT 
    c.id,
    c.title,
    c.virality_score,
    SUM(pm.views) as total_views,
    SUM(pm.likes) as total_likes
FROM clips c
LEFT JOIN performance_metrics pm ON c.id = pm.clip_id
WHERE c.status = 'ready'
GROUP BY c.id, c.title, c.virality_score
ORDER BY total_views DESC NULLS LAST;
