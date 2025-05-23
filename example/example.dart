import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:cross_isolate_messenger/cross_isolate_messenger.dart'; // Assuming you copied PersistentQueue here

class MyMessage {
  final String id;
  final String payload;
  MyMessage(this.id, this.payload);

  Map<String, dynamic> toJson() => {'id': id, 'payload': payload};
  static MyMessage fromJson(Map<String, dynamic> json) =>
      MyMessage(json['id'], json['payload']);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize UI queue
  final queue = await PersistentQueue.getInstance<MyMessage>(
    MyMessage.fromJson,
    (msg) => msg.toJson(),
  );
  queue.bindUIIsolate();
  queue.stream.listen((msg) async {
    print("UI Isolate received: ${msg.payload}");
    await queue.ack(msg.id);
  });

  // Spawn background isolate
  Isolate.spawn(runBackgroundIsolate, null);

  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('PersistentQueue Example'))),
    ),
  );
}

void runBackgroundIsolate(_) async {
  // Must initialize shared_preferences in isolate
  WidgetsFlutterBinding.ensureInitialized();

  final queue = await PersistentQueue.getInstance<MyMessage>(
    MyMessage.fromJson,
    (msg) => msg.toJson(),
  );

  // Simulate sending a message
  await queue.send(
    MyMessage(
      'msg-id-${DateTime.now().millisecondsSinceEpoch}',
      'Hello from background isolate!',
    ),
  );
}
