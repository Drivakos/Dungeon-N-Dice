-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- =====================================================
-- GAME SAVES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS game_saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_name VARCHAR(255) NOT NULL,
    character_data JSONB NOT NULL,
    game_state JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_play_time_seconds INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);

-- =====================================================
-- STORY MEMORIES TABLE (for RAG)
-- =====================================================
CREATE TABLE IF NOT EXISTS story_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    -- Content
    content TEXT NOT NULL,
    summary TEXT, -- AI-generated summary for quick retrieval
    
    -- Memory type and importance
    memory_type VARCHAR(50) NOT NULL, -- 'event', 'npc_interaction', 'location', 'quest', 'combat', 'discovery', 'dialogue'
    importance INTEGER DEFAULT 5, -- 1-10 scale, higher = more important
    
  -- Embedding for semantic search
  embedding vector(768), -- Using 768 dimensions (nomic-embed-text)
    
    -- Metadata
    location VARCHAR(255),
    involved_npcs TEXT[], -- Array of NPC names
    involved_items TEXT[], -- Array of item names
    tags TEXT[], -- Flexible tagging
    
    -- Timestamps
    game_timestamp TIMESTAMP WITH TIME ZONE, -- In-game time
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- For conversation context
    turn_number INTEGER,
    is_player_action BOOLEAN DEFAULT false
);

-- =====================================================
-- NPC MEMORIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS npc_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    npc_name VARCHAR(255) NOT NULL,
    npc_id VARCHAR(255),
    
    -- Relationship with player
    relationship_score INTEGER DEFAULT 50, -- 0-100, 50 = neutral
    first_met_at TIMESTAMP WITH TIME ZONE,
    last_interaction_at TIMESTAMP WITH TIME ZONE,
    interaction_count INTEGER DEFAULT 0,
    
    -- NPC's memory of player
    known_facts TEXT[], -- Facts NPC knows about player
    player_reputation VARCHAR(50), -- 'unknown', 'friendly', 'hostile', 'ally', 'enemy'
    
    -- NPC's current state
    current_location VARCHAR(255),
    current_disposition VARCHAR(50), -- 'friendly', 'neutral', 'hostile', 'scared', etc.
    
    -- Embedding for NPC personality/context
    personality_embedding vector(768),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(save_id, npc_name)
);

-- =====================================================
-- LOCATION MEMORIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS location_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    location_name VARCHAR(255) NOT NULL,
    location_type VARCHAR(100), -- 'tavern', 'dungeon', 'town', 'wilderness', etc.
    
    -- Discovery info
    discovered_at TIMESTAMP WITH TIME ZONE,
    times_visited INTEGER DEFAULT 1,
    last_visited_at TIMESTAMP WITH TIME ZONE,
    
    -- Description and changes
    initial_description TEXT,
    current_description TEXT,
    changes_made TEXT[], -- What the player changed
    
    -- Inhabitants and items
    known_npcs TEXT[],
    known_items TEXT[],
    known_secrets TEXT[],
    
    -- Embedding
    description_embedding vector(768),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(save_id, location_name)
);

-- =====================================================
-- QUEST PROGRESS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS quest_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    quest_name VARCHAR(255) NOT NULL,
    quest_giver VARCHAR(255),
    
    -- Status
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'completed', 'failed', 'abandoned'
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Details
    description TEXT,
    objectives JSONB, -- Array of objectives with completion status
    rewards_given JSONB,
    
    -- Story relevance
    main_story BOOLEAN DEFAULT false,
    importance INTEGER DEFAULT 5,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(save_id, quest_name)
);

-- =====================================================
-- CHAT HISTORY TABLE (full conversation log)
-- =====================================================
CREATE TABLE IF NOT EXISTS chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    -- Message content
    role VARCHAR(20) NOT NULL, -- 'player', 'dm', 'system'
    content TEXT NOT NULL,
    
    -- Metadata
    message_type VARCHAR(50), -- 'action', 'narration', 'dialogue', 'combat', 'system'
    turn_number INTEGER NOT NULL,
    
    -- Optional embedding for semantic search
    embedding vector(768),
    
    -- Combat info if applicable
    combat_data JSONB,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- STORY SUMMARIES TABLE (for context management)
-- =====================================================
CREATE TABLE IF NOT EXISTS story_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    -- Summary content
    summary TEXT NOT NULL,
    
    -- What was summarized
    messages_summarized INTEGER NOT NULL,
    start_turn INTEGER NOT NULL,
    end_turn INTEGER NOT NULL,
    
    -- Running summary (accumulated from all previous summaries)
    is_running_summary BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for story summaries
CREATE INDEX IF NOT EXISTS idx_story_summaries_save_id ON story_summaries(save_id);
CREATE INDEX IF NOT EXISTS idx_story_summaries_running ON story_summaries(save_id, is_running_summary);

-- =====================================================
-- WORLD FACTS TABLE (general world knowledge)
-- =====================================================
CREATE TABLE IF NOT EXISTS world_facts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    save_id UUID NOT NULL REFERENCES game_saves(id) ON DELETE CASCADE,
    
    fact_type VARCHAR(50) NOT NULL, -- 'lore', 'rumor', 'history', 'geography', 'politics'
    subject VARCHAR(255), -- What/who this fact is about
    content TEXT NOT NULL,
    
    -- Source of information
    learned_from VARCHAR(255),
    learned_at_location VARCHAR(255),
    
    -- Reliability
    is_verified BOOLEAN DEFAULT false,
    is_rumor BOOLEAN DEFAULT false,
    
    -- Embedding
    embedding vector(768),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Story memories indexes
CREATE INDEX IF NOT EXISTS idx_story_memories_save_id ON story_memories(save_id);
CREATE INDEX IF NOT EXISTS idx_story_memories_type ON story_memories(memory_type);
CREATE INDEX IF NOT EXISTS idx_story_memories_importance ON story_memories(importance DESC);
CREATE INDEX IF NOT EXISTS idx_story_memories_embedding ON story_memories USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- NPC memories indexes
CREATE INDEX IF NOT EXISTS idx_npc_memories_save_id ON npc_memories(save_id);
CREATE INDEX IF NOT EXISTS idx_npc_memories_name ON npc_memories(npc_name);

-- Location memories indexes  
CREATE INDEX IF NOT EXISTS idx_location_memories_save_id ON location_memories(save_id);
CREATE INDEX IF NOT EXISTS idx_location_memories_name ON location_memories(location_name);

-- Chat history indexes
CREATE INDEX IF NOT EXISTS idx_chat_history_save_id ON chat_history(save_id);
CREATE INDEX IF NOT EXISTS idx_chat_history_turn ON chat_history(save_id, turn_number);
CREATE INDEX IF NOT EXISTS idx_chat_history_embedding ON chat_history USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- World facts indexes
CREATE INDEX IF NOT EXISTS idx_world_facts_save_id ON world_facts(save_id);
CREATE INDEX IF NOT EXISTS idx_world_facts_type ON world_facts(fact_type);
CREATE INDEX IF NOT EXISTS idx_world_facts_embedding ON world_facts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- =====================================================
-- FUNCTIONS FOR RAG
-- =====================================================

-- Function to search similar memories
CREATE OR REPLACE FUNCTION search_similar_memories(
    p_save_id UUID,
    p_query_embedding vector(768),
    p_limit INTEGER DEFAULT 5,
    p_memory_types TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    summary TEXT,
    memory_type VARCHAR(50),
    importance INTEGER,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sm.id,
        sm.content,
        sm.summary,
        sm.memory_type,
        sm.importance,
        1 - (sm.embedding <=> p_query_embedding) as similarity
    FROM story_memories sm
    WHERE sm.save_id = p_save_id
        AND sm.embedding IS NOT NULL
        AND (p_memory_types IS NULL OR sm.memory_type = ANY(p_memory_types))
    ORDER BY sm.embedding <=> p_query_embedding
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to search chat history
CREATE OR REPLACE FUNCTION search_chat_history(
    p_save_id UUID,
    p_query_embedding vector(768),
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    role VARCHAR(20),
    content TEXT,
    turn_number INTEGER,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ch.id,
        ch.role,
        ch.content,
        ch.turn_number,
        1 - (ch.embedding <=> p_query_embedding) as similarity
    FROM chat_history ch
    WHERE ch.save_id = p_save_id
        AND ch.embedding IS NOT NULL
    ORDER BY ch.embedding <=> p_query_embedding
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get recent important memories
CREATE OR REPLACE FUNCTION get_important_memories(
    p_save_id UUID,
    p_min_importance INTEGER DEFAULT 7,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    summary TEXT,
    memory_type VARCHAR(50),
    importance INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sm.id,
        sm.content,
        sm.summary,
        sm.memory_type,
        sm.importance
    FROM story_memories sm
    WHERE sm.save_id = p_save_id
        AND sm.importance >= p_min_importance
    ORDER BY sm.importance DESC, sm.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_game_saves_updated_at
    BEFORE UPDATE ON game_saves
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_npc_memories_updated_at
    BEFORE UPDATE ON npc_memories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_location_memories_updated_at
    BEFORE UPDATE ON location_memories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_quest_progress_updated_at
    BEFORE UPDATE ON quest_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- =====================================================
-- SAMPLE DATA (Optional - for testing)
-- =====================================================

-- Insert a sample save for testing
-- INSERT INTO game_saves (id, save_name, character_data, game_state)
-- VALUES (
--     'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
--     'Test Adventure',
--     '{"name": "TestHero", "class": "Fighter", "level": 1}',
--     '{"currentScene": "Tavern", "gold": 100}'
-- );

COMMENT ON TABLE story_memories IS 'Stores all significant story events for RAG retrieval';
COMMENT ON TABLE npc_memories IS 'Tracks NPC knowledge and relationships with the player';
COMMENT ON TABLE location_memories IS 'Stores discovered locations and their state';
COMMENT ON TABLE chat_history IS 'Full conversation history with optional embeddings';
COMMENT ON TABLE story_summaries IS 'AI-generated summaries for context compression';
COMMENT ON TABLE world_facts IS 'General world knowledge learned by the player';

