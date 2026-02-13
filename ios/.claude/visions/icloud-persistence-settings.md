# Implementation Vision: iCloud Drive Persistence + Settings Page

**Created:** 2026-02-12
**Status:** Planning

## 1. Overview

### Problem Statement
The Songbook app currently stores all songs in SwiftData (on-device only). Users who manage their songwriting projects as folders in iCloud Drive have no way to use those folders as the song library in the app. Additionally, there is no way to open the Songbook app directly from iCloud Drive when browsing song folders in the Files app.

### Goals
- Add a Settings page with a toggle between two persistence modes: **SwiftData** (current behavior) and **iCloud Drive**
- In iCloud Drive mode, let the user pick a root folder and browse its nested structure as their song library
- Introduce a custom `.songbook` file type that marks a folder as a "song" and enables deep-linking from Files/iCloud Drive into the app
- Full CRUD in iCloud Drive mode: create song folders, edit lyrics, delete songs
- Offline-capable iCloud browsing

### Success Metrics
- User can toggle between SwiftData and iCloud modes without data loss in either store
- User can browse arbitrarily nested folder structures in iCloud Drive
- Tapping a `.songbook` file in the iOS Files app opens the Songbook app to that song
- Creating a `.songbook` file via the "+" button immediately transitions to the lyric editor
- The app loads the full folder tree at startup in under ~2 seconds for a typical library

### Stakeholders
- Songwriters who manage song projects as folder structures in iCloud Drive
- Existing users who want to keep using the in-app SwiftData store

## 2. Requirements

### Functional Requirements
1. **Settings Page** accessible via a gear icon in both the HomeView and BrowseView toolbars
2. **Persistence Toggle**: switch between "In-App" (SwiftData) and "iCloud Drive" modes
3. **iCloud Folder Picker**: when enabling iCloud mode, prompt the user to select a root folder via `UIDocumentPickerViewController`
4. **Folder Browsing**: display a unified list of the root folder's contents, recursively scanned at startup
   - Folders containing a `{title}.songbook` file are **song folders** (shown with a music note or similar icon)
   - Folders without a `*.songbook` file are **category folders** (shown with a folder icon, tappable to drill in). "Category" is purely inferential — there is no marker file or metadata; any folder without a `.songbook` file is treated as a navigable category.
5. **Custom `.songbook` File Type**:
   - JSON format mirroring the SwiftData Song model
   - Registered as a custom UTType so iOS knows the app handles it
   - Tapping a `.songbook` file anywhere in iOS opens the Songbook app and navigates to that song
6. **"+" Button**: always visible in BrowseView toolbar at every folder level. Creates a **new subfolder + `.songbook` file** within the current directory (prompts for a song title, creates `Song Title/Song Title.songbook`, and transitions to the editor).
7. **"Make This a Song" Action**: contextual action available when the user navigates into a folder that has no `*.songbook` file. Adds a `{folder name}.songbook` file to that folder, converting it from a category into a song. Useful for folders that already exist in iCloud Drive. Can appear as a button in the empty/non-song state of a folder.
8. **Full CRUD in iCloud Mode**:
   - **Create**: "+" button creates new subfolder + `.songbook` file; "Make This a Song" converts existing folder
   - **Read**: parse `.songbook` JSON for title, lyrics, timestamps
   - **Update**: edit lyrics/title in EditorView, write back to `.songbook` file
   - **Delete**: remove song folder (with confirmation)
9. **Independent Stores**: switching modes just changes which library is visible; no migration between stores
10. **Full Recursive Scan at Startup**: on launch (in iCloud mode), scan the entire root folder tree to build the browsable hierarchy and enable search across all songs

### Non-Functional Requirements
- **Performance:** Full folder scan completes in <2s for libraries of ~200 songs
- **Offline:** App caches the folder tree and downloaded `.songbook` files locally; works without connectivity
- **Reliability:** Use `NSFileCoordinator` / `NSFilePresenter` for safe iCloud file access
- **Security:** Store the root folder's security-scoped bookmark in UserDefaults/Keychain so the app retains access across launches

### Must-Have vs. Nice-to-Have

**MVP Scope:**
- Settings page with persistence toggle
- iCloud folder picker + security-scoped bookmark persistence
- Recursive folder scan at startup
- `.songbook` file creation, reading, writing
- Unified list browsing with drill-down
- Custom UTType registration for `.songbook` (deep-link from Files app)
- Offline caching of folder tree and `.songbook` files

**Future Enhancements:**
- Audio/video file display, recording, and upload within song folders
- Text note files alongside `.songbook` in song folders
- Export SwiftData songs to iCloud Drive (migration)
- iCloud Drive change monitoring (live updates if files change externally)
- Search within iCloud song lyrics (not just titles)

## 3. Constraints

### Technical Constraints
- **iOS 26.0+ deployment target** (modern APIs available)
- **SwiftUI + SwiftData** existing architecture must be preserved for in-app mode
- **iCloud Drive access** requires UIDocumentPickerViewController for folder selection (no direct path access)
- **Security-scoped bookmarks** required to retain folder access across app launches
- **NSFileCoordinator** required for safe reads/writes to iCloud-coordinated files

### Business Constraints
- Solo developer project
- No backend changes needed (the API is only used for the Inspire feature, which works with either persistence mode)

### Integration Constraints
- The EditorView currently takes a `@Bindable Song` (SwiftData model). In iCloud mode, it needs to work with a different data source (the `.songbook` file). This is the central architectural challenge.
- The Inspire feature (`APIClient.suggest`) only needs the song text, so it works regardless of persistence mode.

### Compliance/Security
- The app must request iCloud Drive access via the standard document picker (no entitlement needed for document picker approach, but iCloud entitlement is needed for `NSMetadataQuery`)
- Security-scoped bookmarks must be stored securely
- User data in `.songbook` files is user-controlled and stays in their iCloud Drive

## 4. Technical Context

### Existing Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   SongbookApp    │────▶│    HomeView      │────▶│   EditorView     │
│  (SwiftData      │     │  (@Query songs)  │     │  (@Bindable Song)│
│   container)     │     │  List + Search   │     │  Title + Lyrics  │
└──────────────────┘     └──────────────────┘     │  Save + Inspire  │
                                                   └──────────────────┘
```

**Current data flow:**
1. `SongbookApp` creates a `.modelContainer(for: Song.self)`
2. `HomeView` uses `@Query` to reactively fetch all songs sorted by `updatedAt`
3. `NavigationLink(value: song)` pushes to `EditorView`
4. `EditorView` uses `@Bindable var song: Song` for two-way binding
5. Save calls `context.save()` on the SwiftData ModelContext

### Relevant Files and Components
- `SongbookApp.swift` - App entry point, SwiftData container setup (12 lines)
- `Song.swift` - SwiftData `@Model` with id, title, text, createdAt, updatedAt (19 lines)
- `HomeView.swift` - Song list, search, create sheet, delete (133 lines)
- `EditorView.swift` - Lyric editor, Inspire flow, CursorTextEditor (310 lines)
- `InspireOptionsSheet.swift` - Parameters for AI suggestion
- `APIClient.swift` - Backend API integration

### Existing Patterns
- **SwiftData @Query**: HomeView uses `@Query(sort: \Song.updatedAt, order: .reverse)` for reactive list updates
- **@Bindable binding**: EditorView binds directly to SwiftData model properties
- **Sheet-based flows**: Create song and Inspire features use `.sheet()` presentation
- **NavigationStack + navigationDestination**: Type-safe navigation with `Song.self` as destination value
- **UIViewRepresentable**: CursorTextEditor wraps UITextView for cursor position tracking

### Dependencies
- **Internal**: SwiftUI, SwiftData, UIKit (for CursorTextEditor)
- **External**: Backend API at `lyricsheets-api-lnfivdl47a-ue.a.run.app` (Inspire feature only)
- **New dependencies needed**: None (all iCloud/file APIs are system frameworks)

## 5. Proposed Approach

### Architecture Overview

Use **conditional views** based on the selected persistence mode. `SettingsStore` determines which mode is active. HomeView (SwiftData) and BrowseView (iCloud) are independent — both pass raw bindings to a shared EditorView (per Decision 1).

```
┌──────────────────────────────────────────────────────────────┐
│                         SongbookApp                           │
│  ┌─────────────┐                                             │
│  │SettingsStore│──── mode = .swiftData ──▶ ┌──────────┐     │
│  │ (persists   │                           │ HomeView │     │
│  │  user prefs)│                           │(@Query)  │──┐  │
│  │             │                           └──────────┘  │  │
│  │             │                                         │  │
│  │             │── mode = .iCloud ──▶ ┌──────────────┐   │  │
│  │             │                      │  BrowseView  │   │  │
│  │             │                      │ (FolderNode) │───┤  │
│  └─────────────┘                      └──────────────┘   │  │
│                                                          ▼  │
│                                  Bindings ──▶ ┌──────────┐  │
│                                  (title,text, │EditorView│  │
│                                   save closure│(shared)  │  │
│                                               └──────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Key Components

1. **`SettingsStore`** (new, `@Observable` class)
   - Persists the selected mode via `UserDefaults` (not `@AppStorage`, which is a view-level property wrapper)
   - Stores the iCloud root folder security-scoped bookmark
   - Published properties: `persistenceMode`, `rootFolderBookmark`, `rootFolderURL`

2. **`SongFile`** (new, struct)
   - The in-memory representation of a `.songbook` JSON file
   - Properties mirror `Song`: `id`, `title`, `text`, `createdAt`, `updatedAt`
   - Conforms to `Codable`, `Identifiable`, `Hashable` (needed for `ForEach` and `navigationDestination`)
   - Also stores `fileURL: URL` for write-back

3. **`FolderNode`** (new, struct or class)
   - Represents a node in the folder tree
   - Conforms to `Identifiable`, `Hashable` (needed for `ForEach` and `navigationDestination`)
   - Properties: `name`, `url`, `children: [FolderNode]`, `songFile: SongFile?`
   - `isSong: Bool` — true if the folder contains a `*.songbook` file
   - Used to build the browsable tree from the recursive scan

4. **`iCloudScanService`** (new)
   - Performs the recursive scan of the root folder at startup
   - Returns a `FolderNode` tree
   - Uses `FileManager.contentsOfDirectory(at:)` with `NSFileCoordinator`
   - Parses `.songbook` files to populate `SongFile` metadata
   - **Important:** Must call `url.startAccessingSecurityScopedResource()` before file access and `url.stopAccessingSecurityScopedResource()` when done. This applies to the root URL resolved from the bookmark — all file operations within that scope require it. Should run on a background thread/actor since coordinated file access can block.

5. **`BrowseView`** (new)
   - The iCloud-mode equivalent of HomeView
   - Takes a `FolderNode` and displays its children as a unified list
   - Category folders show a folder icon and navigate deeper
   - Song folders show a music icon and navigate to EditorView
   - Note: HomeView has a `private struct SongCard` that renders song rows (title, snippet, date). Consider extracting it so BrowseView can reuse it for consistent row styling.
   - "+" button in toolbar creates a new subfolder + `.songbook` file (new song) and transitions to editor
   - "Make This a Song" action when inside a non-song folder — adds `.songbook` to convert it
   - Search filters across all songs in the tree (since we have the full scan)

6. **`SettingsView`** (new)
   - Gear icon in toolbar opens this
   - Toggle between "In-App" and "iCloud Drive"
   - When iCloud is selected: shows folder picker, displays current root folder path
   - Option to change root folder

7. **`SongbookDocument`** (new, UTType registration)
   - Register `com.palmernix.songbook` as a custom UTType in Info.plist
   - File extension: `.songbook`
   - Conforms to `public.json`, `public.data`
   - Register the app as a handler for this type
   - Handle `onOpenURL` or scene delegate to navigate to the song when opened from Files

8. **Modified `EditorView`**
   - Currently depends on `@Bindable var song: Song` (SwiftData)
   - Refactored to accept `Binding<String>` for title and text, plus a save closure (per Decision 1). Both HomeView and BrowseView provide these bindings from their respective data sources.
   - On save: the closure either calls `context.save()` (SwiftData) or writes JSON to the `.songbook` file (iCloud)
   - iCloud file writes should use `NSFileCoordinator` and happen off the main thread (coordinated writes can block)
   - Note: The current `touch()` method sets `updatedAt` on every keystroke. In iCloud mode, `updatedAt` should be set **on save only** (inside the save closure), not on every change.

### `.songbook` File Schema

The `.songbook` file is named after the song title at creation time (e.g., `My Song Title.songbook`). This makes it visible and tappable in the iOS Files app. The folder containing it may share the same name (e.g., `My Song Title/My Song Title.songbook`). If the song is later renamed via EditorView, the title in the JSON is updated but the **file and folder names are not renamed** for MVP — the JSON `title` field is the source of truth for display. File/folder renaming can be added as a future enhancement.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "My Song Title",
  "text": "Verse 1 lyrics here...\n\nChorus lyrics here...",
  "createdAt": "2026-02-12T10:30:00Z",
  "updatedAt": "2026-02-12T14:45:00Z"
}
```

Note: Use `JSONEncoder.dateEncodingStrategy = .iso8601` and `JSONDecoder.dateDecodingStrategy = .iso8601` to match this schema. Swift's default encodes dates as floating-point epoch numbers.

### Data Flow (iCloud Mode)

```
App Launch
    │
    ▼
SettingsStore reads mode = .iCloud, resolves bookmark → rootURL
    │
    ▼
iCloudScanService.scan(rootURL) → FolderNode tree
    │
    ▼
BrowseView displays root FolderNode children
    │
    ├── Tap category folder → BrowseView(node: child)
    │
    ├── Tap song folder → EditorView(songFile: node.songFile)
    │
    ├── Tap "+" → create new subfolder + .songbook → EditorView
    │
    └── "Make This a Song" in non-song folder → add .songbook → EditorView
```

### Deep-Link Flow (Files App → Songbook)

```
User taps .songbook file in Files app
    │
    ▼
iOS launches Songbook app with file URL
    │
    ▼
SongbookApp.onOpenURL receives URL
    │
    ▼
App reads .songbook JSON, creates SongFile
    │
    ▼
NavigationStack programmatically navigates to EditorView(songFile:)
```

### API/Interface Changes
- **New UTType**: `com.palmernix.songbook` (exported type)
- **New entitlements**: `com.apple.developer.icloud-container-identifiers` (if using NSMetadataQuery)
- **Info.plist**: The project currently uses `GENERATE_INFOPLIST_FILE = YES` with no explicit Info.plist. Document types, exported UTIs, and URL schemes need to be registered — either by creating an Info.plist or through Xcode target build settings.
- **No API changes**: Backend Inspire feature is persistence-agnostic

## 6. Technical Decisions

### Decision 1: EditorView Abstraction Strategy
- **Options considered:**
  - A) Protocol `EditableSong` that both `Song` and `SongFile` conform to, EditorView accepts the protocol
  - B) Convert `SongFile` to a temporary `Song` in-memory, use existing EditorView unchanged
  - C) Make EditorView accept raw bindings (`Binding<String>` for title/text) instead of a model object
- **Chosen:** C — Raw bindings
- **Rationale:** Simplest approach. EditorView already only uses `song.title`, `song.text`, and `song.updatedAt`. Passing these as bindings makes it persistence-agnostic without introducing protocols or temporary objects. The save action becomes a closure parameter.
- **Trade-offs:** Slightly more parameters on EditorView init, but avoids any protocol/wrapper complexity.

### Decision 2: Folder Access Strategy
- **Options considered:**
  - A) `UIDocumentPickerViewController` for folder selection + security-scoped bookmarks
  - B) CloudKit/NSMetadataQuery for iCloud container access
  - C) UIDocumentBrowserViewController as the primary UI
- **Chosen:** A — Document picker + bookmarks
- **Rationale:** The user wants to pick ANY folder in their iCloud Drive (not just an app-specific container). Document picker is the standard way to get user-granted access to arbitrary locations. Security-scoped bookmarks persist this access across launches.
- **Trade-offs:** Requires bookmark management. If the bookmark becomes stale (user moves the folder), the app needs to handle re-selection gracefully.

### Decision 3: Folder Tree Representation
- **Options considered:**
  - A) Flat list of all songs (ignore folder structure)
  - B) Recursive tree structure with drill-down navigation
- **Chosen:** B — Tree structure
- **Rationale:** The user explicitly wants flexible nesting with category folders. The tree naturally represents the iCloud Drive structure and enables drill-down browsing.
- **Trade-offs:** More complex navigation state, but aligns with user mental model of their folder structure.

### Decision 4: Startup Scan vs. Lazy Load
- **Chosen:** Full recursive scan at startup
- **Rationale:** For a typical songwriter library (<500 songs), scanning folder metadata is sub-second. This enables immediate full-text search across all song titles and provides a complete picture on launch. A loading indicator covers the brief scan time.
- **Trade-offs:** Slightly slower cold start for very large libraries, but this is unlikely for the target use case.

## 7. Implementation Roadmap

### Phase 1: Foundation — Settings + Data Models
- Create `SettingsStore` as `@Observable` class with `UserDefaults`-backed persistence mode
- Create `SongFile` Codable struct (mirrors Song model)
- Create `FolderNode` struct for tree representation
- Create `SettingsView` with mode toggle UI
- Wire gear icon in HomeView and BrowseView toolbars to open SettingsView
- Persist mode selection in UserDefaults

### Phase 2: iCloud Folder Access
- Implement folder picker (wrapping `UIDocumentPickerViewController` in SwiftUI)
- Implement security-scoped bookmark save/restore
- Create `iCloudScanService` with recursive folder enumeration
- Parse `.songbook` files found during scan into `SongFile` objects
- Build `FolderNode` tree from scan results
- Handle errors: stale bookmarks, permission denied, missing folders

### Phase 3: Browse UI
- Create `BrowseView` for iCloud folder navigation
- Unified list: category folders (folder icon, drill-down) + song folders (song icon, open editor)
- "+" button to create new subfolder + `.songbook` file and transition to editor
- "Make This a Song" action for converting existing non-song folders
- Search across all songs in the scanned tree
- Loading state during initial scan
- Empty states for empty folders (with "Make This a Song" option where applicable)
- Update `SongbookApp` root view to conditionally show HomeView or BrowseView based on mode

### Phase 4: EditorView Refactor
- Refactor EditorView to accept `Binding<String>` for title and text instead of `@Bindable Song`
- Add a save closure parameter (SwiftData save vs. file write)
- Create `.songbook` file write-back logic using `NSFileCoordinator`
- Ensure Inspire feature works identically in both modes
- Create song from iCloud mode: new folder + `.songbook` file

### Phase 5: Custom UTType + Deep Linking
- Define `UTType.songbook` as exported type (`com.palmernix.songbook`)
- Register document types and exported UTIs (note: no explicit Info.plist exists currently — project uses `GENERATE_INFOPLIST_FILE`)
- Add `onOpenURL` handler in SongbookApp to handle `.songbook` file opens
- Parse incoming URL, read `.songbook` file, navigate to EditorView
- Handle edge case: app opened via deep-link but iCloud mode not configured

### Phase 6: Offline + Polish
- Ensure scanned folder tree is cached locally for offline access
- Cache `.songbook` file contents locally
- Handle file coordination conflicts gracefully
- Add loading/progress indicators for scan
- Handle stale bookmark recovery (prompt to re-select folder)
- Handle deleted/moved folders gracefully
- Test mode switching back and forth

### File Structure Changes
```
Songbook/Songbook/
├── SongbookApp.swift                (modified - conditional root view, onOpenURL)
├── Song.swift                       (unchanged)
├── HomeView.swift                   (modified - add gear icon to toolbar)
├── EditorView.swift                 (modified - accept bindings instead of @Bindable Song)
├── InspireOptionsSheet.swift        (unchanged)
├── APIClient.swift                  (unchanged)
├── Settings/
│   ├── SettingsStore.swift          (new - persistence mode, bookmark management)
│   └── SettingsView.swift           (new - settings UI with toggle + folder picker)
├── iCloud/
│   ├── SongFile.swift               (new - Codable struct for .songbook JSON)
│   ├── FolderNode.swift             (new - tree node for folder structure)
│   ├── iCloudScanService.swift      (new - recursive folder scanner)
│   ├── FolderPickerView.swift       (new - UIDocumentPickerViewController wrapper)
│   ├── BookmarkManager.swift        (new - security-scoped bookmark persistence)
│   └── BrowseView.swift             (new - folder browsing UI)
└── SongbookDocument/
    └── UTType+Songbook.swift        (new - UTType definition)
```

## 8. Testing Strategy

### Unit Tests
- `SongFile` JSON encoding/decoding (round-trip)
- `FolderNode` tree building from mock file structure
- `SettingsStore` mode persistence and bookmark storage
- `iCloudScanService` with mock FileManager (if feasible)
- `.songbook` file schema validation

### Integration Tests
- Folder picker → bookmark save → bookmark restore → folder access
- Scan folder → build tree → display in BrowseView
- Create `.songbook` → read back → verify contents
- Edit lyrics → save to `.songbook` → verify file updated
- Deep-link URL → parse → navigate to correct song

### Edge Cases
- Root folder deleted or moved after bookmark saved
- `.songbook` file with malformed JSON
- Empty root folder (no subfolders)
- Folder with `.songbook` file AND subfolders (treat as song — `.songbook` takes precedence, subfolders ignored)
- Very deeply nested folder structure (10+ levels)
- Two `.songbook` files in same folder (use first found, sorted alphabetically)
- File permissions revoked
- Switching modes while EditorView is open

### Manual Testing
- Full flow: Settings → enable iCloud → pick folder → browse → create song → edit → save → verify in Files app
- Deep-link: Files app → tap `.songbook` → Songbook opens to correct song
- Offline: enable airplane mode → browse cached songs → edit → reconnect → verify sync
- Mode switch: create songs in SwiftData → switch to iCloud → switch back → verify both libraries intact

## 9. Risks and Mitigation

| Risk | Likelihood | Impact | Mitigation Strategy |
|------|------------|--------|---------------------|
| Security-scoped bookmark becomes stale | Medium | High | Detect stale bookmark on launch, prompt user to re-select folder. Store folder path as fallback display. |
| File coordination conflicts (external edits) | Low | Medium | Use NSFileCoordinator for all reads/writes. Show conflict resolution UI if needed. |
| Large folder trees slow down startup | Low | Medium | Show progress indicator. If scan exceeds 3s, consider switching to lazy+background scan. |
| Deep-link opens app but iCloud mode not configured | Medium | Medium | Show onboarding/setup flow when opened via URL without iCloud mode enabled. |
| Offline cache becomes out of sync | Medium | Low | Re-scan on next online launch. Timestamp-based conflict detection. |
| User moves/renames root folder in Files | Low | High | Bookmark will be stale. Detect and prompt to re-select. |

### Known Unknowns
- **NSMetadataQuery vs FileManager**: Need to determine if `NSMetadataQuery` is needed for monitoring changes or if periodic re-scans suffice for MVP. FileManager with security-scoped bookmarks may be sufficient.
- **iCloud entitlement requirements**: The document picker approach may not require iCloud entitlements (since it's user-initiated access), but `NSMetadataQuery` would. Need to verify during implementation.
- **Bookmark data size**: Security-scoped bookmark data can be large-ish. Need to verify UserDefaults is appropriate or if Keychain is better.

## 10. Documentation Requirements

- [ ] Update README with iCloud Drive feature description
- [ ] Document `.songbook` file schema for users who want to create files manually
- [ ] Code comments for bookmark management and file coordination logic

## 11. Future Considerations

### Potential Extensions
- Audio/video files in song folders (playback, recording, upload from Photos/Files)
- Text note files alongside `.songbook`
- Live file monitoring via `NSMetadataQuery` (auto-refresh when files change externally)
- Migration tool: export SwiftData songs to iCloud Drive folders
- Shared/collaborative song folders
- Tags/metadata beyond the current Song model fields
- Search within lyric text across all iCloud songs

### Technical Debt
- EditorView refactor to bindings is a healthy change that improves testability regardless of iCloud feature
- The current `try? context.save()` error swallowing in HomeView should be improved when adding the iCloud write path

### Scalability Path
- Current approach (full scan at startup) works for <1000 songs
- For larger libraries: background indexing + SQLite cache of folder tree
- For real-time sync: `NSMetadataQuery` monitoring with incremental tree updates

---

## Appendix

### References
- [Apple: Providing Access to Directories](https://developer.apple.com/documentation/uikit/view_controllers/providing_access_to_directories)
- [Apple: NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [Apple: Defining a Custom Uniform Type Identifier](https://developer.apple.com/documentation/uniformtypeidentifiers/defining_file_and_data_types_for_your_app)
- [Apple: Security-Scoped Bookmarks](https://developer.apple.com/documentation/security/app_sandbox/accessing_files_from_the_macos_app_sandbox#3023294)

### Open Questions
- [ ] Should the app allow creating new category folders from within the app, or only song folders?
- [x] When a folder has BOTH a `.songbook` file AND subfolders → **Treat as a song; subfolders are ignored/not visible in the app.** The `.songbook` file takes precedence.
- [x] Should the "+" button be available at every folder level, or only in leaf folders? → **Every folder level.** The "+" button is always visible in BrowseView toolbar.
