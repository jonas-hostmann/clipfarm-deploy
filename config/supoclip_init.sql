-- Database initialization script for SupoClip
-- Create database schema with required tables

-- Enable UUID extension for generating UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (compatible with Prisma schema)
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    "emailVerified" BOOLEAN NOT NULL DEFAULT false,
    image VARCHAR(500),
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    password_hash VARCHAR(255),
    -- Default font preferences
    default_font_family VARCHAR(100) DEFAULT 'TikTokSans-Regular',
    default_font_size INTEGER DEFAULT 24,
    default_font_color VARCHAR(7) DEFAULT '#FFFFFF',
    notify_on_completion BOOLEAN NOT NULL DEFAULT true,
    -- Monetization and billing fields
    is_admin BOOLEAN NOT NULL DEFAULT false,
    plan VARCHAR(20) NOT NULL DEFAULT 'free',
    subscription_status VARCHAR(20) NOT NULL DEFAULT 'inactive',
    subscription_provider VARCHAR(20),
    stripe_customer_id VARCHAR(255) UNIQUE,
    stripe_subscription_id VARCHAR(255) UNIQUE,
    billing_period_start TIMESTAMP WITH TIME ZONE,
    billing_period_end TIMESTAMP WITH TIME ZONE,
    trial_ends_at TIMESTAMP WITH TIME ZONE
);

-- Source table (created before tasks since tasks reference sources)
CREATE TABLE IF NOT EXISTS sources (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    type VARCHAR(20) CHECK (type IN ('youtube', 'video_url')) NOT NULL,
    title VARCHAR(500) NOT NULL,
    url VARCHAR(1000),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_id VARCHAR(36) REFERENCES sources(id) ON DELETE SET NULL,
    generated_clips_ids VARCHAR(36)[],
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    progress_message TEXT,
    font_family VARCHAR(100) DEFAULT 'TikTokSans-Regular',
    font_size INTEGER DEFAULT 24,
    font_color VARCHAR(7) DEFAULT '#FFFFFF',
    caption_template VARCHAR(50) DEFAULT 'default',
    include_broll BOOLEAN DEFAULT false,
    processing_mode VARCHAR(20) NOT NULL DEFAULT 'fast',
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cache_hit BOOLEAN NOT NULL DEFAULT false,
    error_code VARCHAR(80),
    stage_timings_json TEXT,
    completion_notification_sent_at TIMESTAMP WITH TIME ZONE,
    share_token VARCHAR(64),
    share_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Generated clips table
CREATE TABLE IF NOT EXISTS generated_clips (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    task_id VARCHAR(36) NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    start_time VARCHAR(20) NOT NULL,
    end_time VARCHAR(20) NOT NULL,
    duration FLOAT NOT NULL,
    text TEXT,
    relevance_score FLOAT NOT NULL,
    reasoning TEXT,
    clip_order INTEGER NOT NULL,
    virality_score INTEGER DEFAULT 0,
    hook_score INTEGER DEFAULT 0,
    engagement_score INTEGER DEFAULT 0,
    value_score INTEGER DEFAULT 0,
    shareability_score INTEGER DEFAULT 0,
    hook_type VARCHAR(50),
    hook_title VARCHAR(200),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS processing_cache (
    cache_key VARCHAR(255) PRIMARY KEY,
    source_url TEXT NOT NULL,
    source_type VARCHAR(20) NOT NULL,
    video_path TEXT,
    transcript_text TEXT,
    analysis_json TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Better Auth tables
CREATE TABLE IF NOT EXISTS session (
    id VARCHAR(36) PRIMARY KEY,
    "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "ipAddress" VARCHAR(255),
    "userAgent" TEXT,
    "userId" VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS account (
    id VARCHAR(36) PRIMARY KEY,
    "accountId" VARCHAR(255) NOT NULL,
    "providerId" VARCHAR(255) NOT NULL,
    "userId" VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    "accessToken" TEXT,
    "refreshToken" TEXT,
    "idToken" TEXT,
    "accessTokenExpiresAt" TIMESTAMP WITH TIME ZONE,
    "refreshTokenExpiresAt" TIMESTAMP WITH TIME ZONE,
    scope TEXT,
    password TEXT,
    "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS verification (
    id VARCHAR(36) PRIMARY KEY,
    identifier VARCHAR(255) NOT NULL,
    value VARCHAR(255) NOT NULL,
    "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
    "createdAt" TIMESTAMP WITH TIME ZONE,
    "updatedAt" TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS stripe_webhook_events (
    id VARCHAR(255) PRIMARY KEY,
    type VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS revenuecat_webhook_events (
    id VARCHAR(255) PRIMARY KEY,
    type VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    encrypted_value TEXT NOT NULL,
    prefer_admin_value BOOLEAN NOT NULL DEFAULT false,
    updated_by VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_keys (
    id VARCHAR(36) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL DEFAULT 'API Key',
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    key_prefix VARCHAR(16) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_source_id ON tasks(source_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_processing_mode ON tasks(processing_mode);
CREATE INDEX IF NOT EXISTS idx_tasks_completed_at ON tasks(completed_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_share_token ON tasks(share_token) WHERE share_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sources_created_at ON sources(created_at);
CREATE INDEX IF NOT EXISTS idx_processing_cache_source_url ON processing_cache(source_url);
CREATE INDEX IF NOT EXISTS idx_generated_clips_task_id ON generated_clips(task_id);
CREATE INDEX IF NOT EXISTS idx_generated_clips_clip_order ON generated_clips(clip_order);
CREATE INDEX IF NOT EXISTS idx_generated_clips_created_at ON generated_clips(created_at);
CREATE INDEX IF NOT EXISTS idx_session_token ON session(token);
CREATE INDEX IF NOT EXISTS idx_session_userId ON session("userId");
CREATE INDEX IF NOT EXISTS idx_account_userId ON account("userId");
CREATE INDEX IF NOT EXISTS idx_verification_identifier ON verification(identifier);
CREATE INDEX IF NOT EXISTS idx_app_settings_updated_by ON app_settings(updated_by);
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);

-- Trigger functions
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION update_updatedAt_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."updatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers (idempotent)
DROP TRIGGER IF EXISTS update_users_updatedAt ON users;
CREATE TRIGGER update_users_updatedAt BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();
DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_sources_updated_at ON sources;
CREATE TRIGGER update_sources_updated_at BEFORE UPDATE ON sources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_generated_clips_updated_at ON generated_clips;
CREATE TRIGGER update_generated_clips_updated_at BEFORE UPDATE ON generated_clips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_app_settings_updated_at ON app_settings;
CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON app_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_session_updatedAt ON session;
CREATE TRIGGER update_session_updatedAt BEFORE UPDATE ON session FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();
DROP TRIGGER IF EXISTS update_account_updatedAt ON account;
CREATE TRIGGER update_account_updatedAt BEFORE UPDATE ON account FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();
DROP TRIGGER IF EXISTS update_verification_updatedAt ON verification;
CREATE TRIGGER update_verification_updatedAt BEFORE UPDATE ON verification FOR EACH ROW EXECUTE FUNCTION update_updatedAt_column();
