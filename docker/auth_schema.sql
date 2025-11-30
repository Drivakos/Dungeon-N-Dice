-- =====================================================
-- USER AUTHENTICATION SCHEMA
-- =====================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    email_verified BOOLEAN DEFAULT false
);

-- Sessions table for JWT refresh tokens
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token VARCHAR(500) UNIQUE NOT NULL,
    device_info TEXT,
    ip_address VARCHAR(45),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_revoked BOOLEAN DEFAULT false
);

-- Update game_saves to link to users
ALTER TABLE game_saves ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE game_saves ADD COLUMN IF NOT EXISTS character_name VARCHAR(255);
ALTER TABLE game_saves ADD COLUMN IF NOT EXISTS character_class VARCHAR(100);
ALTER TABLE game_saves ADD COLUMN IF NOT EXISTS character_level INTEGER DEFAULT 1;
ALTER TABLE game_saves ADD COLUMN IF NOT EXISTS last_played_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE game_saves ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_game_saves_user_id ON game_saves(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_refresh_token ON sessions(refresh_token);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_user_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_user_updated_at();

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to get user's save files
CREATE OR REPLACE FUNCTION get_user_saves(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    save_name VARCHAR(255),
    character_name VARCHAR(255),
    character_class VARCHAR(100),
    character_level INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    last_played_at TIMESTAMP WITH TIME ZONE,
    total_play_time_seconds INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        gs.id,
        gs.save_name,
        gs.character_name,
        gs.character_class,
        gs.character_level,
        gs.created_at,
        gs.last_played_at,
        gs.total_play_time_seconds
    FROM game_saves gs
    WHERE gs.user_id = p_user_id
        AND gs.is_active = true
    ORDER BY gs.last_played_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to clean expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sessions 
    WHERE expires_at < NOW() OR is_revoked = true;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE users IS 'User accounts for authentication';
COMMENT ON TABLE sessions IS 'Active user sessions with refresh tokens';

