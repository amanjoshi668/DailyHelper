CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(160) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(40) DEFAULT '',
    role VARCHAR(20) NOT NULL DEFAULT 'customer', -- 'customer' | 'professional'
    preferred_lang VARCHAR(10) NOT NULL DEFAULT 'en',
    password_hash TEXT,
    google_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_vaults (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS worker_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    name_en VARCHAR(160) NOT NULL,
    name_hi VARCHAR(160) DEFAULT '',
    trade VARCHAR(40) NOT NULL DEFAULT 'electrician',
    skills JSONB NOT NULL DEFAULT '[]'::jsonb,
    service_pins JSONB NOT NULL DEFAULT '["560034"]'::jsonb,
    experience_years INT NOT NULL DEFAULT 3,
    visit_fee_inr INT NOT NULL DEFAULT 149,
    hourly_rate_inr INT NOT NULL DEFAULT 250,
    daily_rate_inr INT NOT NULL DEFAULT 900,
    custom_rates JSONB NOT NULL DEFAULT '[]'::jsonb,
    upi_id VARCHAR(120) DEFAULT '',
    phone VARCHAR(40) DEFAULT '',
    languages VARCHAR(120) DEFAULT 'Hindi, English',
    verified BOOLEAN NOT NULL DEFAULT TRUE,
    is_online BOOLEAN NOT NULL DEFAULT TRUE,
    blocked_slots JSONB NOT NULL DEFAULT '[]'::jsonb,
    rating_avg NUMERIC(3,2) NOT NULL DEFAULT 4.80,
    jobs_completed INT NOT NULL DEFAULT 0,
    khata_today_inr INT NOT NULL DEFAULT 0,
    khata_month_inr INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bookings (
    id VARCHAR(40) PRIMARY KEY,
    customer_id VARCHAR(120) NOT NULL,
    customer_name VARCHAR(160) NOT NULL,
    customer_phone VARCHAR(40) DEFAULT '',
    worker_id VARCHAR(120) NOT NULL,
    worker_name VARCHAR(160) NOT NULL,
    trade VARCHAR(40) NOT NULL,
    pin_code VARCHAR(12) NOT NULL,
    locality VARCHAR(160) DEFAULT '',
    full_address TEXT NOT NULL,
    booking_date VARCHAR(60) NOT NULL,
    slot_window VARCHAR(60) NOT NULL,
    issue_note TEXT DEFAULT '',
    visit_fee_inr INT NOT NULL DEFAULT 149,
    final_amount_inr INT,
    payment_method VARCHAR(40),
    status VARCHAR(30) NOT NULL DEFAULT 'requested', -- 'requested' | 'confirmed' | 'in_progress' | 'completed' | 'declined' | 'cancelled'
    customer_rating INT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(120) NOT NULL,
    booking_id VARCHAR(40),
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    is_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_dismissed);

CREATE TABLE IF NOT EXISTS bug_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_email VARCHAR(255) DEFAULT 'anonymous@tester.local',
    description TEXT NOT NULL,
    page_context VARCHAR(100) DEFAULT '',
    app_version VARCHAR(50) DEFAULT '1.0.0',
    device_info JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(20) DEFAULT 'open', -- 'open' | 'in_progress' | 'resolved'
    resolution_notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON bug_reports(status);

CREATE TABLE IF NOT EXISTS mobile_google_sessions (
    session_id VARCHAR(80) PRIMARY KEY,
    role VARCHAR(20) NOT NULL DEFAULT 'customer',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    token TEXT,
    user_json JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Safe additive migrations for existing live Cloud SQL databases
ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS daily_rate_inr INT NOT NULL DEFAULT 900;
ALTER TABLE worker_profiles ADD COLUMN IF NOT EXISTS custom_rates JSONB NOT NULL DEFAULT '[]'::jsonb;
