# ESP32 Bluetooth SPP Protocol Contract

This app uses newline-delimited Bluetooth SPP lines and follows the ESP32 firmware contract:

- Every outbound message ends with `\n`.
- Stream includes mixed line types:
  - control markers (`<VOICE_START>`, `<VOICE_READY>`, `<VOICE_END>`, etc.)
  - JSON commands (`{"command":"..."}`)
  - chat frame markers (`<MSG_START:uid:message_id>`, `<MSG_END>`)
  - chat body lines
  - base64 voice chunk lines while receiving voice

## Priority Order

1. Voice markers
2. Voice chunk lines
3. JSON commands
4. Chat framing/body

## Outgoing Commands

- `sync_profile`
- `sync_sos`
- `send_sos`
- `get_profile`
- `send_seen`
- `set_rf_channel`

## Incoming Commands

- `msg_sent`
- `msg_seen`
- `profile_response`
- `profile_queued`
- `busy_voice`

## Notes

- During active voice, conflicting operations are limited in UI.
- Profile lookup queue responses are surfaced as app state.
- SOS metadata line format (`[SOS_META] severity=... timestamp_ms=...`) is parsed from framed chat bodies.
