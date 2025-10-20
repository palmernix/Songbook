# Lyric Sheets
*A personal songwriting companion with AI lyric inspiration.*

---

## Overview
**Lyric Sheets** is a SwiftUI app for writing, organizing, and refining song lyrics.  
Each song has its own lyric sheet — simple, focused, and local-first.  
An integrated AI “Inspire” button uses a lightweight FastAPI + LangChain backend to generate single-line lyric suggestions that match your personal writing style.

---

## ✨ Features

### iOS App (`/app-ios`)
- Built in **SwiftUI** with **SwiftData** for local persistence.
- “Notes-style” lyric editor with section headers (Verse, Chorus, Bridge, etc.).
- **Inspire** button for real-time lyric suggestions:
  - Generates **one single-line** continuation.
  - Context-aware (current section + full song text).
  - Considers your **writing voice**, learned from saved songs.
  - Optional user-defined parameters: rhyme scheme, syllable count, mood, style.
- Local-first storage for single-user usage.
    - Persistence via Firebase / iCloud as a future state if cross-device sync is a requirement.

### Backend API (`/api-python`)
- Built with **FastAPI** + **LangChain** + **Chroma** vector database.
- `/suggest` → returns a single lyric suggestion.
- `/ingest/snapshot` → embeds and stores all lines from a saved song.
- Uses **OpenAI GPT-4o-mini** for generation and **text-embedding-3-small** for style embeddings.
- Retrieves similar lines from your personal catalog (“your-voice memory”) + optional reference material for stylistic influence.
- Stateless for song text — only embeddings + metadata are stored.
- Deployable to **Google Cloud Run**

**Data flow**
1. You write lyrics → press **Save** → iOS app sends snapshot to `/ingest/snapshot`.
2. Backend splits text into lines → embeds → upserts into Chroma (vector DB).
3. When you press **Inspire**, app sends `/suggest` with current lyrics + context.
4. Backend retrieves stylistically similar lines + reference examples → builds a prompt → calls GPT-4o-mini → returns one new line.

---

### 🧱 Repo Architecture
song-spark/
│
├── app-ios/           # SwiftUI + SwiftData iOS app
│   ├── SongSpark.xcodeproj
│   ├── Sources/
│   └── …
│
├── api-python/        # FastAPI backend
│   ├── main.py
│   ├── pyproject.toml (Poetry)
│   ├── .env (not committed)
│   ├── chroma_db/ (vector store)
│   └── …
│
├── contracts/         # Shared schemas / prompts (optional)
│
├── .gitignore
├── LICENSE
└── README.md

---

## 🧰 Tech Stack

| Layer | Tech |
|-------|------|
| iOS app | SwiftUI, SwiftData |
| Backend | Python, FastAPI, LangChain |
| Embeddings | OpenAI `text-embedding-3-small` |
| LLM | OpenAI `gpt-4o-mini` |
| Vector DB | Chroma |
| Hosting | Google Cloud Run |
| Dependency management | Poetry |
| Version control | GitHub monorepo |

