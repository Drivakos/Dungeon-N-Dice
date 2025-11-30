# 🐉 AI Dungeon Master

**An AI-powered text-based D&D 5e adventure game**

Experience infinite adventures with an AI Dungeon Master that creates unique stories, remembers your journey, and runs authentic D&D mechanics.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white)

---

## ✨ Features

- 🎭 **AI Dungeon Master** - Dynamic storytelling powered by local AI
- ⚔️ **D&D 5e Mechanics** - Authentic dice rolls, combat, and skill checks
- 🧠 **Long-term Memory** - The AI remembers NPCs, locations, and your choices
- 💾 **Cloud Saves** - Multiple save files with user accounts
- 📱 **Cross-platform** - Web, Android, and iOS
- 🔒 **Privacy-first** - Runs locally, your stories stay yours

---

## 📋 Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| [Flutter](https://flutter.dev/docs/get-started/install) | 3.0+ | Game client |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Latest | Database & API |
| [Ollama](https://ollama.ai/) | Latest | Local AI models |

---

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/ai-dungeon-master.git
cd ai-dungeon-master
```

### Step 2: Install Ollama Models

Download and install [Ollama](https://ollama.ai/), then pull the required models:

```bash
# Chat model (for storytelling)
ollama pull qwen2.5:3b-instruct

# Embedding model (for memory/RAG)
ollama pull nomic-embed-text
```

**Alternative chat models** (choose based on your hardware):

| Model | VRAM Required | Quality |
|-------|---------------|---------|
| `qwen2.5:3b-instruct` | 4GB | Good |
| `qwen2.5:7b-instruct` | 8GB | Better |
| `llama3.2:3b-instruct` | 4GB | Good |
| `mistral:7b-instruct` | 8GB | Better |

### Step 3: Configure Environment Variables

```bash
# Copy the example environment file
cp env.example .env

# Edit .env with your settings (optional for local dev)
# For production, update passwords and secrets!
```

### Step 4: Start the Backend Services

```bash
# Start PostgreSQL + API (database tables created automatically!)
docker compose up -d

# Verify services are running
docker ps
```

You should see:
- `dnd_game_db` - PostgreSQL database ✅
- `dnd_game_api` - REST API for saves ✅
- `dnd_pgadmin` - Database admin (optional) ✅

> 💡 **Database tables are created automatically** on first startup!
> 
> If you need to reset the database:
> ```bash
> docker compose down -v  # Removes data
> docker compose up -d    # Fresh start
> ```

### Step 5: Install Flutter Dependencies

```bash
flutter pub get
```

### Step 6: Run the Game

```bash
# Web (recommended for testing)
flutter run -d chrome

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

---

## 🎮 How to Play

### Starting a New Game

1. Launch the app
2. (Optional) Sign in to enable cloud saves
3. Click **"NEW ADVENTURE"**
4. Create your character:
   - Choose a race (Human, Elf, Dwarf, etc.)
   - Choose a class (Fighter, Wizard, Rogue, etc.)
   - Name your hero
5. Begin your adventure!

### Gameplay

- **Type anything** - Describe what you want to do
- The AI DM will narrate the results
- **Skill checks** appear automatically when needed
- **Combat** triggers when you encounter enemies

### Quick Actions

Use the suggestion buttons or type freely:
- `"I attack the goblin"` → Triggers combat
- `"I search the room"` → Perception check
- `"I try to persuade the guard"` → Charisma check
- `"I cast fireball"` → Uses spell slot

### Saving Your Game

- **Auto-save** - Progress saves automatically
- **Manual save** - Go to Settings → Save Game
- **Cloud saves** - Sign in to sync across devices

---

## ⚙️ Configuration

### Ollama Settings

In the game, go to **Settings** and configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Ollama URL | `http://localhost:11434` | Ollama API endpoint |
| Chat Model | `qwen2.5:3b-instruct` | Model for storytelling |

### Database Access (pgAdmin)

Access your database at: http://localhost:5050

- **Email:** `admin@dndgame.com`
- **Password:** `admin123`

**Connect to database:**
- Host: `postgres`
- Port: `5432`
- Database: `dnd_adventure`
- Username: `dnd_admin`
- Password: `dragon_slayer_2024`

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                      │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐  │
│  │  Story  │  │ Combat   │  │Character│  │  Inventory   │  │
│  │ Screen  │  │ Manager  │  │  Sheet  │  │   & Quests   │  │
│  └────┬────┘  └────┬─────┘  └────┬────┘  └──────┬───────┘  │
│       └────────────┴─────────────┴───────────────┘          │
│                           │                                  │
│                    ┌──────┴──────┐                          │
│                    │ Game Master │                          │
│                    └──────┬──────┘                          │
└───────────────────────────┼──────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
    ┌───────▼───────┐ ┌─────▼─────┐ ┌──────▼──────┐
    │    Ollama     │ │  Game API │ │  PostgreSQL │
    │ (AI Models)   │ │  (Auth)   │ │  (pgvector) │
    │               │ │           │ │             │
    │ qwen2.5:3b    │ │ /auth/*   │ │ game_saves  │
    │ nomic-embed   │ │ /saves/*  │ │ memories    │
    └───────────────┘ └───────────┘ └─────────────┘
```

---

## 🎲 D&D Mechanics

### Supported Features

| Feature | Status | Notes |
|---------|--------|-------|
| Ability Scores | ✅ | STR, DEX, CON, INT, WIS, CHA |
| Skill Checks | ✅ | All 18 skills |
| Saving Throws | ✅ | Based on class proficiencies |
| Combat | ✅ | Initiative, attacks, damage |
| Spellcasting | 🔄 | Basic implementation |
| Leveling | ✅ | XP-based progression |
| Inventory | ✅ | Items, gold, equipment |
| Quests | ✅ | Track objectives |

### Dice Rolling

The game uses authentic D&D dice:
- d20 for attacks and checks
- Damage dice based on weapons
- Advantage/disadvantage system
- Critical hits on natural 20

---

## 🔧 Troubleshooting

### "Connection refused" to Ollama

```bash
# Check if Ollama is running
ollama list

# Start Ollama if needed
ollama serve
```

### "Database not found" or "relation does not exist" errors

```bash
# Reset and recreate the database (this deletes all data!)
docker compose down -v
docker compose up -d

# Tables are created automatically - wait a few seconds, then verify:
docker exec -i dnd_game_db psql -U dnd_admin -d dnd_adventure -c "\dt"
```

### Manual migration (if needed)

If you added new SQL files after initial setup:

```bash
docker exec -i dnd_game_db psql -U dnd_admin -d dnd_adventure -f /docker-entrypoint-initdb.d/01_init.sql
docker exec -i dnd_game_db psql -U dnd_admin -d dnd_adventure -f /docker-entrypoint-initdb.d/02_auth.sql
```

### API returns 500 errors

```bash
# Check API logs
docker logs dnd_game_api --tail 50

# Restart the API
docker restart dnd_game_api
```

### Flutter build errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run -d chrome
```

---

## 🛠️ Development

### Project Structure

```
lib/
├── core/
│   ├── constants/      # Game constants (D&D rules)
│   ├── router/         # Navigation
│   └── theme/          # UI theme
├── data/
│   ├── models/         # Data models
│   ├── services/       # AI, Auth, Memory services
│   └── repositories/   # Data access
├── domain/
│   └── game_engine/    # Combat, dice, skill checks
└── presentation/
    ├── providers/      # State management (Riverpod)
    ├── screens/        # UI screens
    └── widgets/        # Reusable components
```

### Running Tests

```bash
flutter test
```

### Building for Production

```bash
# Web
flutter build web

# Android APK
flutter build apk

# iOS
flutter build ios
```

---

## 📄 License

This project is for educational purposes. D&D mechanics are inspired by the SRD 5.1.

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - UI framework
- [Ollama](https://ollama.ai/) - Local AI inference
- [Riverpod](https://riverpod.dev/) - State management
- [pgvector](https://github.com/pgvector/pgvector) - Vector similarity search
- D&D 5e SRD - Game mechanics reference

---

## 🐛 Known Issues

- Text input flickers on Flutter Web (known Flutter bug)
- First AI response may be slow (model loading)
- Combat UI needs manual refresh in some cases

---

**Made with ❤️ for tabletop RPG fans**

*Roll for initiative!* 🎲
