import 'dart:convert';

enum ParserState {
  idle,
  awaitingVoiceReady,
  transmittingVoice,
  receivingVoice,
  receivingChatFrame,
  queuedProfileWait,
}

enum ProtocolEventType {
  control,
  json,
  chatFrameComplete,
  voiceChunk,
  malformed,
}

class ProtocolEvent {
  const ProtocolEvent({
    required this.type,
    this.control,
    this.json,
    this.chatHeader,
    this.chatBody,
    this.voiceChunk,
    this.rawLine,
  });

  final ProtocolEventType type;
  final String? control;
  final Map<String, dynamic>? json;
  final ChatFrameHeader? chatHeader;
  final String? chatBody;
  final String? voiceChunk;
  final String? rawLine;
}

class ChatFrameHeader {
  const ChatFrameHeader({
    required this.senderUid,
    required this.messageId,
    required this.rawHeader,
    required this.malformed,
  });

  final String senderUid;
  final String messageId;
  final String rawHeader;
  final bool malformed;
}

class Esp32ProtocolParser {
  ParserState _state = ParserState.idle;
  ParserState get state => _state;

  ChatFrameHeader? _activeHeader;
  final StringBuffer _chatBodyBuffer = StringBuffer();

  List<ProtocolEvent> consumeLine(String rawLine) {
    final line = rawLine.replaceAll('\r', '').trim();
    if (line.isEmpty) return const <ProtocolEvent>[];

    if (_state == ParserState.receivingVoice) {
      if (line == '<VOICE_END>') {
        _state = ParserState.idle;
        return <ProtocolEvent>[
          const ProtocolEvent(type: ProtocolEventType.control, control: '<VOICE_END>'),
        ];
      }
      return <ProtocolEvent>[
        ProtocolEvent(type: ProtocolEventType.voiceChunk, voiceChunk: line),
      ];
    }

    if (line == '<VOICE_START>') {
      _state = ParserState.receivingVoice;
      return <ProtocolEvent>[
        const ProtocolEvent(type: ProtocolEventType.control, control: '<VOICE_START>'),
      ];
    }
    if (line == '<VOICE_READY>' || line == '<VOICE_DENY_BUSY>' || line == '<VOICE_DONE>' || line == '<VOICE_END>') {
      if (line == '<VOICE_DONE>' || line == '<VOICE_END>' || line == '<VOICE_DENY_BUSY>') {
        _state = ParserState.idle;
      }
      return <ProtocolEvent>[
        ProtocolEvent(type: ProtocolEventType.control, control: line),
      ];
    }

    if (line.startsWith('<MSG_START:')) {
      _state = ParserState.receivingChatFrame;
      _activeHeader = _parseHeader(line);
      _chatBodyBuffer.clear();
      return const <ProtocolEvent>[];
    }

    if (_state == ParserState.receivingChatFrame) {
      if (line == '<MSG_END>') {
        final header = _activeHeader ??
            const ChatFrameHeader(
              senderUid: 'UNKNOWN',
              messageId: '',
              rawHeader: '<MSG_START:UNKNOWN>',
              malformed: true,
            );
        final body = _chatBodyBuffer.toString().trimRight();
        _activeHeader = null;
        _chatBodyBuffer.clear();
        _state = ParserState.idle;
        return <ProtocolEvent>[
          ProtocolEvent(
            type: ProtocolEventType.chatFrameComplete,
            chatHeader: header,
            chatBody: body,
          ),
        ];
      }
      if (_chatBodyBuffer.isNotEmpty) _chatBodyBuffer.writeln();
      _chatBodyBuffer.write(line);
      return const <ProtocolEvent>[];
    }

    final maybeJson = _tryDecodeJson(line);
    if (maybeJson != null) {
      final command = (maybeJson['command'] ?? '').toString();
      if (command == 'profile_queued') {
        _state = ParserState.queuedProfileWait;
      } else if (_state == ParserState.queuedProfileWait && command == 'profile_response') {
        _state = ParserState.idle;
      }
      return <ProtocolEvent>[
        ProtocolEvent(type: ProtocolEventType.json, json: maybeJson, rawLine: line),
      ];
    }

    return <ProtocolEvent>[
      ProtocolEvent(type: ProtocolEventType.malformed, rawLine: line),
    ];
  }

  ChatFrameHeader _parseHeader(String line) {
    final m = RegExp(r'^<MSG_START:(.*?)>$').firstMatch(line);
    if (m == null) {
      return ChatFrameHeader(
        senderUid: 'UNKNOWN',
        messageId: '',
        rawHeader: line,
        malformed: true,
      );
    }
    final body = m.group(1) ?? 'UNKNOWN';
    final parts = body.split(':');
    if (parts.length >= 2) {
      final uid = parts.first.trim();
      final messageId = parts.sublist(1).join(':').trim();
      return ChatFrameHeader(
        senderUid: uid.isEmpty ? 'UNKNOWN' : uid,
        messageId: messageId,
        rawHeader: line,
        malformed: uid.isEmpty || messageId.isEmpty,
      );
    }
    return ChatFrameHeader(
      senderUid: body.isEmpty ? 'UNKNOWN' : body,
      messageId: '',
      rawHeader: line,
      malformed: true,
    );
  }

  Map<String, dynamic>? _tryDecodeJson(String line) {
    if (!line.startsWith('{') || !line.contains('"command"')) return null;
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
