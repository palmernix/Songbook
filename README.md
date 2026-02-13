# Songbook

A personal songwriting companion for iOS.

---

## Overview

Songbook is a SwiftUI app for writing, recording, and organizing songs. Each song is a collection of entries — lyrics, notes, audio recordings, and video — all in one place. An integrated "Inspire" feature uses a lightweight backend to generate lyric suggestions that match your personal writing style.

---

## Features

### Song Organization and Browser
- Create and manage songs with multiple entry types per song (lyrics, notes, audio, video).
- Two storage modes: **local** (SwiftData) or **iCloud Drive** with folder-based organization.
- Custom `.songbook` file format with Quick Look thumbnails and deep linking — tap a `.songbook` file in iCloud Drive to open it directly in the app.

### Lyrics Editor
- Rich text editing with bold, italic, underline, and heading levels (H1–H3).
- Bullet lists with automatic continuation, indentation, and smart removal.
- Live word count.

### Notes
- Same rich text editor as lyrics, for freeform ideas, structure notes, or anything else.

### Audio
- Record directly in-app or import audio files.
- Waveform visualization with scrubbing.
- Timestamped comments — mark moments and tap to seek back to them.

### Video
- Record video or import from the photo library.
- Custom player with aspect-ratio-aware layout.
- Timestamped comments, same as audio.

### Inspire
- AI lyric suggestions from the lyrics editor toolbar.
- Uses your songwriting voice and specified lyrical references to help you come up with your next word, line, or more.
- Context-aware: considers the current line, surrounding stanza, and full song text.
- Optional parameters for style, mood, rhyme scheme, syllable count, and section type.
- Preview suggestions before inserting, with options to refine or regenerate.

---

## Architecture

```
Songbook/
├── ios/                # SwiftUI iOS app
│   ├── Songbook.xcodeproj
│   ├── Songbook/           # App source
│   ├── SongbookTests/
│   ├── SongbookUITests/
│   └── SongbookThumbnail/  # Quick Look thumbnail extension
│
├── lyric-engine/       # FastAPI backend
│   ├── main.py
│   ├── pyproject.toml
│   └── ...
│
├── Makefile
├── LICENSE
└── README.md
```

## Tech Stack

| Layer | Tech |
|-------|------|
| iOS app | SwiftUI, SwiftData, AVFoundation |
| Backend | Python, FastAPI, LangChain |
| Embeddings | OpenAI `text-embedding-3-small` |
| LLM | OpenAI `gpt-4o-mini` |
| Vector DB | Chroma |
| Hosting | Google Cloud Run |
