import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

/// Minimal Pusher-protocol client for Laravel Reverb: one private channel, reconnects with backoff.
class ReverbClient {
  ReverbClient({
    required this.api,
    required this.host,
    required this.port,
    required this.key,
    required this.secure,
    required this.onEvent,
  });

  final ApiClient api;
  final String host;
  final int port;
  final String key;
  final bool secure;

  /// `(eventName, data)` for every event on the subscribed channel.
  final void Function(String event, Map<String, dynamic> data) onEvent;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _ping;
  Timer? _retry;
  String? _channelName;
  var _attempt = 0;
  var _closed = true;

  void connect(String channelName) {
    _channelName = channelName;
    _closed = false;
    _open();
  }

  void disconnect() {
    _closed = true;
    _retry?.cancel();
    _teardown();
    api.socketId = null;
  }

  void _open() {
    _teardown();
    final scheme = secure ? 'wss' : 'ws';
    final url = Uri.parse('$scheme://$host:$port/app/$key?protocol=7&client=lumi-flutter&version=0.1');
    try {
      final channel = WebSocketChannel.connect(url);
      _channel = channel;
      _sub = channel.stream.listen(_onMessage, onDone: _scheduleRetry, onError: (_) => _scheduleRetry());
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _teardown() {
    _ping?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _scheduleRetry() {
    api.socketId = null;
    _ping?.cancel();
    if (_closed) return;
    _retry?.cancel();
    final seconds = min(30, pow(2, _attempt).toInt());
    _attempt++;
    _retry = Timer(Duration(seconds: seconds), _open);
  }

  Future<void> _onMessage(dynamic raw) async {
    if (raw is! String) return;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final event = message['event'] as String? ?? '';
    final data = _data(message['data']);

    switch (event) {
      case 'pusher:connection_established':
        _attempt = 0;
        final socketId = data['socket_id'] as String?;
        api.socketId = socketId;
        final timeout = (data['activity_timeout'] as int?) ?? 30;
        _ping = Timer.periodic(Duration(seconds: timeout), (_) => _send('pusher:ping', {}));
        if (socketId != null) await _subscribe(socketId);
      case 'pusher:ping':
        _send('pusher:pong', {});
      case 'pusher:error':
      case 'pusher_internal:subscription_succeeded':
      case 'pusher:pong':
        break;
      default:
        if (message['channel'] == _channelName) onEvent(event, data);
    }
  }

  Future<void> _subscribe(String socketId) async {
    final channel = _channelName;
    if (channel == null) return;
    try {
      final auth = await api.post('broadcasting/auth', {
        'socket_id': socketId,
        'channel_name': channel,
      });
      _send('pusher:subscribe', {'channel': channel, 'auth': auth['auth']});
    } on ApiException {
      // A revoked token is handled by ApiClient.onUnauthenticated; otherwise retry later.
      _scheduleRetry();
    }
  }

  void _send(String event, Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  static Map<String, dynamic> _data(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }
}
