const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key';
const JWT_EXPIRY = parseInt(process.env.JWT_EXPIRY) || 86400; // 24 hours

// =====================================================
// AUTH MIDDLEWARE
// =====================================================
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};

// =====================================================
// AUTH ROUTES
// =====================================================

// Register new user
app.post('/auth/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    // Check if user exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);

    // Create user
    const result = await pool.query(
      `INSERT INTO users (email, password_hash, display_name)
       VALUES ($1, $2, $3)
       RETURNING id, email, display_name, created_at`,
      [email.toLowerCase(), passwordHash, displayName || email.split('@')[0]]
    );

    const user = result.rows[0];

    // Generate tokens
    const accessToken = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRY }
    );

    const refreshToken = uuidv4();
    
    // Store refresh token
    await pool.query(
      `INSERT INTO sessions (user_id, refresh_token, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '30 days')`,
      [user.id, refreshToken]
    );

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
      },
      accessToken,
      refreshToken,
      expiresIn: JWT_EXPIRY,
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Login
app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    // Find user
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 AND is_active = true',
      [email.toLowerCase()]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Verify password
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Update last login
    await pool.query(
      'UPDATE users SET last_login_at = NOW() WHERE id = $1',
      [user.id]
    );

    // Generate tokens
    const accessToken = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRY }
    );

    const refreshToken = uuidv4();
    
    // Store refresh token
    await pool.query(
      `INSERT INTO sessions (user_id, refresh_token, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '30 days')`,
      [user.id, refreshToken]
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
        avatarUrl: user.avatar_url,
      },
      accessToken,
      refreshToken,
      expiresIn: JWT_EXPIRY,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Refresh token
app.post('/auth/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token required' });
    }

    // Find valid session
    const sessionResult = await pool.query(
      `SELECT s.*, u.email, u.display_name 
       FROM sessions s 
       JOIN users u ON s.user_id = u.id
       WHERE s.refresh_token = $1 
         AND s.expires_at > NOW() 
         AND s.is_revoked = false
         AND u.is_active = true`,
      [refreshToken]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(403).json({ error: 'Invalid refresh token' });
    }

    const session = sessionResult.rows[0];

    // Generate new access token
    const accessToken = jwt.sign(
      { userId: session.user_id, email: session.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRY }
    );

    res.json({
      accessToken,
      expiresIn: JWT_EXPIRY,
    });
  } catch (err) {
    console.error('Refresh error:', err);
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

// Logout
app.post('/auth/logout', authenticateToken, async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      await pool.query(
        'UPDATE sessions SET is_revoked = true WHERE refresh_token = $1',
        [refreshToken]
      );
    }

    res.json({ message: 'Logged out successfully' });
  } catch (err) {
    console.error('Logout error:', err);
    res.status(500).json({ error: 'Logout failed' });
  }
});

// Get current user
app.get('/auth/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, display_name, avatar_url, created_at FROM users WHERE id = $1',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });
  } catch (err) {
    console.error('Get user error:', err);
    res.status(500).json({ error: 'Failed to get user' });
  }
});

// =====================================================
// GAME SAVES ROUTES
// =====================================================

// Get all saves for user
app.get('/saves', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, save_name, character_name, character_class, character_level,
              created_at, last_played_at, total_play_time_seconds, thumbnail_url
       FROM game_saves
       WHERE user_id = $1 AND is_active = true
       ORDER BY last_played_at DESC`,
      [req.user.userId]
    );

    res.json({ saves: result.rows });
  } catch (err) {
    console.error('Get saves error:', err);
    res.status(500).json({ error: 'Failed to get saves' });
  }
});

// Get single save
app.get('/saves/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM game_saves
       WHERE id = $1 AND user_id = $2 AND is_active = true`,
      [req.params.id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Save not found' });
    }

    res.json({ save: result.rows[0] });
  } catch (err) {
    console.error('Get save error:', err);
    res.status(500).json({ error: 'Failed to get save' });
  }
});

// Create new save
app.post('/saves', authenticateToken, async (req, res) => {
  try {
    const { saveName, characterData, gameState } = req.body;

    if (!saveName || !characterData || !gameState) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Extract character info from characterData
    const charName = characterData.name || 'Unknown Hero';
    const charClass = characterData.characterClass?.displayName || characterData.class || 'Adventurer';
    const charLevel = characterData.level || 1;

    const result = await pool.query(
      `INSERT INTO game_saves (
        user_id, save_name, character_data, game_state,
        character_name, character_class, character_level
      )
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, save_name, character_name, character_class, character_level, created_at`,
      [
        req.user.userId,
        saveName,
        JSON.stringify(characterData),
        JSON.stringify(gameState),
        charName,
        charClass,
        charLevel,
      ]
    );

    res.status(201).json({ save: result.rows[0] });
  } catch (err) {
    console.error('Create save error:', err);
    res.status(500).json({ error: 'Failed to create save' });
  }
});

// Update save
app.put('/saves/:id', authenticateToken, async (req, res) => {
  try {
    const { saveName, characterData, gameState, totalPlayTimeSeconds } = req.body;

    // Check ownership
    const checkResult = await pool.query(
      'SELECT id FROM game_saves WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.userId]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Save not found' });
    }

    // Extract character info
    const charName = characterData?.name;
    const charClass = characterData?.characterClass?.displayName || characterData?.class;
    const charLevel = characterData?.level;

    const result = await pool.query(
      `UPDATE game_saves SET
        save_name = COALESCE($1, save_name),
        character_data = COALESCE($2, character_data),
        game_state = COALESCE($3, game_state),
        character_name = COALESCE($4, character_name),
        character_class = COALESCE($5, character_class),
        character_level = COALESCE($6, character_level),
        total_play_time_seconds = COALESCE($7, total_play_time_seconds),
        last_played_at = NOW(),
        updated_at = NOW()
       WHERE id = $8
       RETURNING id, save_name, character_name, character_class, character_level, 
                 last_played_at, total_play_time_seconds`,
      [
        saveName,
        characterData ? JSON.stringify(characterData) : null,
        gameState ? JSON.stringify(gameState) : null,
        charName,
        charClass,
        charLevel,
        totalPlayTimeSeconds,
        req.params.id,
      ]
    );

    res.json({ save: result.rows[0] });
  } catch (err) {
    console.error('Update save error:', err);
    res.status(500).json({ error: 'Failed to update save' });
  }
});

// Delete save (soft delete)
app.delete('/saves/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE game_saves SET is_active = false, updated_at = NOW()
       WHERE id = $1 AND user_id = $2
       RETURNING id`,
      [req.params.id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Save not found' });
    }

    res.json({ message: 'Save deleted successfully' });
  } catch (err) {
    console.error('Delete save error:', err);
    res.status(500).json({ error: 'Failed to delete save' });
  }
});

// =====================================================
// STORY MEMORIES ROUTES (for RAG)
// =====================================================

// Store memory
app.post('/memories', authenticateToken, async (req, res) => {
  try {
    const { saveId, content, summary, memoryType, importance, location, involvedNpcs, tags } = req.body;

    // Verify save belongs to user
    const saveCheck = await pool.query(
      'SELECT id FROM game_saves WHERE id = $1 AND user_id = $2',
      [saveId, req.user.userId]
    );

    if (saveCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Save not found' });
    }

    const result = await pool.query(
      `INSERT INTO story_memories (
        save_id, content, summary, memory_type, importance, location, involved_npcs, tags
      )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, content, memory_type, importance, created_at`,
      [saveId, content, summary, memoryType || 'event', importance || 5, location, involvedNpcs, tags]
    );

    res.status(201).json({ memory: result.rows[0] });
  } catch (err) {
    console.error('Store memory error:', err);
    res.status(500).json({ error: 'Failed to store memory' });
  }
});

// Get memories for save
app.get('/memories/:saveId', authenticateToken, async (req, res) => {
  try {
    const { limit = 50, minImportance = 0, types } = req.query;

    let query = `
      SELECT sm.* FROM story_memories sm
      JOIN game_saves gs ON sm.save_id = gs.id
      WHERE sm.save_id = $1 AND gs.user_id = $2 AND sm.importance >= $3
    `;
    
    const params = [req.params.saveId, req.user.userId, parseInt(minImportance)];

    if (types) {
      query += ` AND sm.memory_type = ANY($4)`;
      params.push(types.split(','));
    }

    query += ` ORDER BY sm.importance DESC, sm.created_at DESC LIMIT $${params.length + 1}`;
    params.push(parseInt(limit));

    const result = await pool.query(query, params);

    res.json({ memories: result.rows });
  } catch (err) {
    console.error('Get memories error:', err);
    res.status(500).json({ error: 'Failed to get memories' });
  }
});

// =====================================================
// HEALTH CHECK
// =====================================================
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (err) {
    res.status(500).json({ status: 'unhealthy', database: 'disconnected' });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🎮 DND Game API running on port ${PORT}`);
});

