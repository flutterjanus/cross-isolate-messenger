import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:collection';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class LruCache<K> {
  final int capacity;
  final Map<K, void> _cache = LinkedHashMap.from({});

  LruCache(this.capacity);

  bool contains(K key) {
    if (!_cache.containsKey(key)) return false;
    _cache.remove(key);
    _cache[key] = null;
    return true;
  }

  void add(K key) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = null;
  }
}

typedef MessageDecoder<T> = T Function(Map<String, dynamic>);

class CrossIsolateQueue<T> {
  final String portName;
  final String queueMapKey;
  final MessageDecoder<T>? decoder;

  static final Map<String, CrossIsolateQueue> _instances = {};

  final StreamController<T> _controller = StreamController<T>.broadcast();
  final LruCache<String> _deduplicationCache = LruCache(100);

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync(
    options: SharedPreferencesOptions(),
  );

  CrossIsolateQueue._internal(this.portName, this.queueMapKey, this.decoder);

  factory CrossIsolateQueue.getInstance(
    String portName, {
    MessageDecoder<T>? decoder,
  }) {
    if (_instances.containsKey(portName)) {
      return _instances[portName] as CrossIsolateQueue<T>;
    }

    final instance = CrossIsolateQueue<T>._internal(
      portName,
      '_queue_$portName',
      decoder,
    );
    _instances[portName] = instance;
    return instance;
  }

  /// Initializes the queue and replays saved messages
  Future<void> initialize() async {
    final ReceivePort receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(receivePort.sendPort, portName);
    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final id = _extractId(message);
        if (!_deduplicationCache.contains(id)) {
          _deduplicationCache.add(id);
          await _enqueue(message);
          final parsed = _parseMessage(message);
          if (parsed != null) _controller.add(parsed);
        }
      }
    });

    await _replayQueue();
  }

  /// The stream to listen to messages
  Stream<T> get stream => _controller.stream.asBroadcastStream();

  /// Send a message to a specific isolate group
  static Future<void> send(
    String portName,
    Map<String, dynamic> message,
  ) async {
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(portName);
    if (sendPort != null) {
      sendPort.send(message);
    } else {
      // Persist if port is not yet ready
      final instance = _instances[portName];
      if (instance != null) {
        await instance._enqueue(message);
      } else {
        throw Exception("Queue not initialized for $portName");
      }
    }
  }

  /// Acknowledge and remove message by id
  Future<void> ack(String id) async {
    final existingJson = await _prefs.getString(queueMapKey);
    if (existingJson == null) return;
    final Map<String, String> messageMap = Map<String, String>.from(
      jsonDecode(existingJson),
    );
    messageMap.remove(id);
    await _prefs.setString(queueMapKey, jsonEncode(messageMap));
  }

  /// Replay old messages
  Future<void> _replayQueue() async {
    final existingJson = await _prefs.getString(queueMapKey);
    final Map<String, String> messageMap =
        existingJson != null
            ? Map<String, String>.from(jsonDecode(existingJson))
            : {};
    for (final entry in messageMap.entries) {
      try {
        final Map<String, dynamic> message = jsonDecode(entry.value);
        final id = entry.key;
        if (!_deduplicationCache.contains(id)) {
          _deduplicationCache.add(id);
          final parsed = _parseMessage(message);
          if (parsed != null) _controller.add(parsed);
        }
      } catch (_) {}
    }
  }

  /// Add message to storage queue
  Future<void> _enqueue(Map<String, dynamic> message) async {
    final id = _extractId(message);
    final existingJson = await _prefs.getString(queueMapKey);
    final Map<String, String> messageMap =
        existingJson != null
            ? Map<String, String>.from(jsonDecode(existingJson))
            : {};

    messageMap[id] = jsonEncode(message);
    await _prefs.setString(queueMapKey, jsonEncode(messageMap));
  }

  /// Parse the message using decoder or cast
  T? _parseMessage(Map<String, dynamic> message) {
    if (decoder != null) {
      return decoder!(message);
    } else {
      return message as T?;
    }
  }

  /// Extract unique ID for deduplication
  static String _extractId(Map<String, dynamic> message) {
    return message['id']?.toString() ??
        message['messageId']?.toString() ??
        message.hashCode.toString();
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _controller.close();
    IsolateNameServer.removePortNameMapping(portName);
    _instances.remove(portName);
  }
}
