# SQLite cache + channel-switch notification – implementation notes

## List of files modified

- `lib/providers/chat_provider.dart`
- `lib/services/sqlite_service.dart`
- `lib/screens/modern_home_screen.dart`
- `lib/screens/local_chat_screen.dart`

## Changes per file

### lib/providers/chat_provider.dart

- **ChatMessage**: Added `isSystem` (bool, default false) and included it in constructor and `copyWith`.
- **addChannelSwitchNotification(int)**: New method; appends a local-only system message ("You are now in Channel X") to `_messages` and notifies.
- **_rfChannelPrefKey**: New constant `'rf_channel_index'` for SharedPreferences (aligned with home screen).
- **_loadCachedMessages()**: Implemented to load from SQLite by current RF channel (`getMessagesByChannel`), map rows to `ChatMessage` (text and voice from `voice_file_path`), replace `_messages` with loaded list, and notify.
- **_persistMessageToCache(ChatMessage, {String? voiceFilePath})**: New; writes one message to SQLite (chat_id = `local_channel_$channel`, channel, optional voice_file_path). Skips when `message.isSystem`. Wrapped in try/catch.
- **_saveVoiceToCache(ChatMessage)**: New; saves voice base64 to app docs `voice_messages/`, then calls `_persistMessageToCache` with path.
- **_addMessage**: After adding to `_messages`, calls `unawaited(_persistMessageToCache(message))` when `!message.isSystem`.
- **_addVoiceMessage**: After adding to `_messages`, calls `unawaited(_saveVoiceToCache(chatMessage))`.
- **stopRecordingAndSend**: After `_messages.add(chatMessage)`, calls `unawaited(_persistMessageToCache(chatMessage, voiceFilePath: recordingPath))`.
- Imports: added `dart:io`, `path_provider`, `path`.

### lib/services/sqlite_service.dart

- **_databaseVersion**: Bumped from 8 to 9.
- **_onCreate (messages table)**: Added columns `channel INTEGER NOT NULL DEFAULT 1`, `voice_file_path TEXT`.
- **_onUpgrade**: Added block for `oldVersion < 9`: ensure `messages` has `channel` and `voice_file_path` via PRAGMA table_info and ALTER TABLE ADD COLUMN if missing.
- **getMessagesByChannel(int channel)**: New method; returns `getMessagesByChatId('local_channel_$channel')`.

### lib/screens/modern_home_screen.dart

- **Channel dropdown onChanged**: After `setRfChannel`, calls `chatProvider.addChannelSwitchNotification(index + 1)` so the user sees "You are now in Channel 1" (etc.) in local chat.

### lib/screens/local_chat_screen.dart

- **ListView itemBuilder**: If `message.isSystem`, returns `_buildSystemMessage(message)` instead of bubble or emergency line.
- **_buildSystemMessage(ChatMessage)**: New widget; centered, muted text, no bubble, with vertical padding.

## Reason for the changes

- **Channel notification**: Show clear in-chat feedback when the user switches RF channel (e.g. "You are now in Channel 2").
- **SQLite cache**: Persist text and voice messages per channel so that after app close or refresh, messages remain in their respective channels without changing send/receive logic.

## How the new feature interacts with existing code

- **Send/receive**: Unchanged. Bluetooth/ESP32 path is still the only driver for real-time send/receive. Cache is write-through (persist after add/send) and read on load.
- **UI**: Still consumes `ChatProvider.messages`. System messages are rendered as centered lines; cache only populates or replaces `_messages` when loading (e.g. initial load or refresh).

## Notes for merging safely

- Migrations run on first launch after merge (DB version 9). Ensure SharedPreferences key for channel is `rf_channel_index` everywhere.
- When touching ChatProvider or SQLite, align: channel index 0–4 (UI) vs channel number 1–5 (storage), and `chat_id` format `local_channel_1` … `local_channel_5`.
- Voice files are stored under app documents in `voice_messages/`. Paths are stored in `voice_file_path`; on load, file is read and base64-decoded for playback.
- Test: close app, reopen, confirm messages load for current channel; switch channel and confirm "You are now in Channel X" appears in chat; send/receive text and voice and confirm they persist and load.

---

## Full local retention (type: text / voice / SOS / AI)

### Additional files / changes

- **lib/services/sqlite_service.dart**: DB version 10. Migration: add columns `type` (TEXT DEFAULT 'text'), `severity_level` (TEXT), `emergency_type` (TEXT), `is_pinned` (INTEGER DEFAULT 0) if missing. Backfill `type = 'voice'` where `message_type = 'voice'`. _onCreate: same columns in messages table for new installs.
- **lib/providers/chat_provider.dart**: **_persistMessageToCache**: set `type` (text/voice/SOS/AI from ChatMessage), `severity_level`, `emergency_type`, `is_pinned`. **_loadCachedMessages**: read `type` (fallback to `message_type`), restore `isEmergency`, `severityLevel`, `emergencyType`, `isPinned` for SOS/AI using `SeverityLevel.fromString` and `EmergencyType.fromString`. **loadMessages**: when `forceRefresh` is true, call `_loadCachedMessages()` so refresh shows SQLite-backed list for current channel.
- **lib/screens/modern_home_screen.dart**: After channel switch and `addChannelSwitchNotification`, call `await chatProvider.loadMessages(forceRefresh: true)` so the chat list shows the new channel’s messages from SQLite.
- **lib/models/emergency_type.dart**: No code change; `SeverityLevel.fromString` and `EmergencyType.fromString` already exist and are used when restoring AI messages from DB.

### Reason

- Full local retention: all message types (text, voice, SOS, AI) are stored and restored so the local chat page shows complete history on app open and refresh, per channel, without changing send/receive behavior.

### Interaction with existing code

- Send/receive unchanged. Restored messages have correct `isEmergency`/`emergencyType`/`severityLevel`/`isPinned` so existing local_chat_screen styling and emergency/AI status line continue to work.

### Merge notes (full retention)

- Run migration on first launch (DB version 10). Use same `type` values everywhere: 'text', 'voice', 'SOS', 'AI'. Test: send/receive text, voice, SOS, and AI-style messages; close app; reopen and refresh; switch channel; confirm all types appear with correct styling and pins.
