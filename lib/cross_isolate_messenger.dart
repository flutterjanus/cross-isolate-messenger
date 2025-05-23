import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

/// A persistent, cross-isolate message queue system using SharedPreferences.
///
/// This queue is designed to work across Flutter isolates, especially useful
/// in scenarios involving background isolates (e.g., Firebase Messaging)
/// communicating with the UI isolate.
///
/// Messages are serialized and persisted using SharedPreferences, ensuring durability
/// across app restarts. Each message is replayed to the UI isolate until it is
/// acknowledged, after which it is garbage-collected.
///
/// - Requires unique `id` in each message map for deduplication.
/// - Only suitable for native platforms (uses SharedPreferences).
///  ### Minimal Example
/// ```dart
/// import 'dart:isolate';
/// import 'package:flutter/material.dart';
/// import 'package:cross_isolate_messenger/cross_isolate_messenger.dart';
/// 
/// class MyMessage {
///   final String id;
///   final String payload;
///   MyMessage(this.id, this.payload);
///
///   Map<String, dynamic> toJson() => {'id': id, 'payload': payload};
///   static MyMessage fromJson(Map<String, dynamic> json) =>
///       MyMessage(json['id'], json['payload']);
/// }
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize UI queue
///   final queue = await PersistentQueue.getInstance<MyMessage>(
///     MyMessage.fromJson,
///     (msg) => msg.toJson(),
///   );
///   queue.bindUIIsolate();
///   queue.stream.listen((msg) async {
///     print("UI Isolate received: \${msg.payload}");
///     await queue.ack(msg.id);
///   });
///
///   // Spawn background isolate
///   Isolate.spawn(runBackgroundIsolate, null);
///
///   runApp(
///     const MaterialApp(
///       home: Scaffold(body: Center(child: Text('PersistentQueue Example'))),
///     ),
///   );
/// }
///
/// void runBackgroundIsolate(_) async {
///   // Must initialize shared_preferences in isolate
///   WidgetsFlutterBinding.ensureInitialized();
///
///   final queue = await PersistentQueue.getInstance<MyMessage>(
///     MyMessage.fromJson,
///     (msg) => msg.toJson(),
///   );
///
///   // Simulate sending a message
///   await queue.send(
///     MyMessage(
///       'msg-id-\${DateTime.now().millisecondsSinceEpoch}',
///       'Hello from background isolate!',
///     ),
///   );
/// }
/// ```
class PersistentQueue<T> {
  static const _queueKey = 'persistent_queue_data';
  static const _ackedKey = 'persistent_queue_acked';
  static const _uiPortName = 'persistent_queue_ui_port';

  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  late SharedPreferencesAsync _prefs;
  Stream<T> stream;
  final StreamController<T> _controller = StreamController.broadcast();

  PersistentQueue._(this.fromJson, this.toJson)
    : stream = StreamController<T>.broadcast().stream;

  /// Returns a singleton-like instance of [PersistentQueue] initialized with
  /// serialization/deserialization functions.
  static Future<PersistentQueue<T>> getInstance<T>(
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final instance = PersistentQueue._(fromJson, toJson);
    instance._prefs = SharedPreferencesAsync(
      options: SharedPreferencesOptions(),
    );
    instance.stream = instance._controller.stream;
    return instance;
  }

  /// Binds this isolate as the UI isolate.
  ///
  /// This sets up a [ReceivePort] that other isolates can send messages to
  /// using a [SendPort] registered under [_uiPortName]. Also replays
  /// any previously unacknowledged messages from storage.
  Future<void> bindUIIsolate() async {
    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(_uiPortName);
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _uiPortName);
    receivePort.listen((msg) {
      if (msg is Map<String, dynamic>) {
        _controller.add(fromJson(msg));
      }
    });
    await _replayPendingMessages();
  }

  /// Enqueues a message and attempts to deliver it to the UI isolate.
  ///
  /// Messages sent from background isolates can use this method. If the
  /// UI isolate is not currently bound, the message will be persisted and
  /// replayed later.
  Future<void> send(T item) async {
    await _enqueue(item);
    _sendToUI(item);
  }

  /// Looks up the registered [SendPort] of the UI isolate
  SendPort? _getUIPort() {
    return IsolateNameServer.lookupPortByName(_uiPortName);
  }

  /// Persists the given item to SharedPreferences.
  Future<void> _enqueue(T item) async {
    final list = await _loadQueue();
    list.add(toJson(item));
    await _saveQueue(list);
  }

  /// Sends the given item to the UI isolate if the SendPort is registered.
  void _sendToUI(T item) {
    final port = _getUIPort();
    if (port != null) {
      port.send(toJson(item));
    }
  }

  /// Replays all persisted messages that have not been acknowledged.
  Future<void> _replayPendingMessages() async {
    final list = await _loadQueue();
    final ackedIds = await _loadAcked();

    for (final item in list) {
      final id = item['id'];
      if (!ackedIds.contains(id) && item.isNotEmpty) {
        _controller.add(fromJson(item));
      }
    }
  }

  /// Marks a message (by ID) as acknowledged and triggers garbage collection.
  ///
  /// This should be called by the UI isolate after it has successfully
  /// handled a message to avoid future replays.
  Future<void> ack(String id) async {
    final acked = await _loadAcked();
    if (!acked.contains(id)) {
      acked.add(id);
      await _prefs.setStringList(_ackedKey, acked);
      await _gc();
    }
  }

  /// Loads the current message queue from SharedPreferences.
  Future<List<Map<String, dynamic>>> _loadQueue() async {
    final jsonString = await _prefs.getString(_queueKey);
    if (jsonString == null) return [];
    try {
      return List<Map<String, dynamic>>.from(json.decode(jsonString));
    } catch (_) {
      return [];
    }
  }

  /// Saves the given queue list to SharedPreferences.
  Future<void> _saveQueue(List<Map<String, dynamic>> list) async {
    await _prefs.setString(_queueKey, json.encode(list));
  }

  /// Loads the list of acknowledged message IDs from SharedPreferences.
  Future<List<String>> _loadAcked() async {
    final list = await _prefs.getStringList(_ackedKey) ?? [];
    return list;
  }

  /// Garbage collects acknowledged messages from the queue.
  ///
  /// Ensures that only unacknowledged messages remain in storage.
  Future<void> _gc() async {
    final queue = await _loadQueue();
    final acked = await _loadAcked();
    final filtered =
        queue.where((item) => !acked.contains(item['id'])).toList();
    await _saveQueue(filtered);
  }

  /// Clears the message queue and acknowledgment list.
  ///
  /// For development or testing only. Removes all persisted state and
  /// unregisters the UI port.
  Future<void> clearAll() async {
    await _prefs.remove(_queueKey);
    await _prefs.remove(_ackedKey);
    IsolateNameServer.removePortNameMapping(_uiPortName);
  }
}
