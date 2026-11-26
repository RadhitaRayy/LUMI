import 'dart:async';
import 'dart:convert';

/// One Server-Sent Event: `event: name` + `data: {json}`.
class SseEvent {
  const SseEvent(this.event, this.data);

  final String event;
  final Map<String, dynamic> data;
}

/// Turns a byte stream into SSE events. Comments and malformed data lines are skipped.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var event = 'message';
  final data = StringBuffer();

  await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        Map<String, dynamic>? decoded;
        try {
          final value = jsonDecode(data.toString());
          if (value is Map<String, dynamic>) decoded = value;
        } catch (_) {}
        if (decoded != null) yield SseEvent(event, decoded);
      }
      event = 'message';
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      if (data.isNotEmpty) data.write('\n');
      data.write(line.substring(5).trimLeft());
    }
  }
}
