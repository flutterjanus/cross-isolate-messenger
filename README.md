# 📨 Cross Isolate Messenger
[![januscaler](https://img.shields.io/badge/powered_by-JanuScaler-b?style=for-the-badge&logo=Januscaler&logoColor=%238884ED&label=Powered%20By&labelColor=white&color=%238884ED)](https://januscaler.com)  

[![pub package](https://img.shields.io/pub/v/cross_isolate_messenger.svg)](https://pub.dartlang.org/packages/cross_isolate_messenger)
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-14-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

**Cross Isolate Messenger** is a lightweight Dart utility for reliable message passing and durability across Flutter isolates.

It ensures that messages are not lost during app lifecycle events by persisting them using `SharedPreferences`, and allows seamless replay and garbage collection.

---

## ✨ Features

- 📨 **Reliable queue**: Ensures messages sent from background isolates reach the UI.
- 🔁 **Replay & persistence**: Messages are stored and replayed until acknowledged.
- 🧼 **Garbage collection**: Acknowledged messages are purged automatically.
- 🔀 **Stream-based**: UI receives messages via `Stream<T>`.
- 🔗 **IsolateNameServer**: Automatically manages isolate communication.

---

## 🧩 Requirements

> ✅ **Only for native platforms (Android, iOS, macOS)** – Uses `SharedPreferences`.

---

## 🚀 Usage

### Define your message

```dart
class MyMessage {
  final String id;
  final String payload;
  MyMessage(this.id, this.payload);

  Map<String, dynamic> toJson() => {'id': id, 'payload': payload};
  static MyMessage fromJson(Map<String, dynamic> json) =>
      MyMessage(json['id'], json['payload']);
}
```

### UI Isolate (Main isolate)

```dart
final queue = await PersistentQueue.getInstance<MyMessage>(
  MyMessage.fromJson,
  (msg) => msg.toJson(),
);
queue.bindUIIsolate();
queue.stream.listen((msg) async {
  print("Received: \${msg.payload}");
  await queue.ack(msg.id);
});
```

### Background Isolate

```dart
final queue = await PersistentQueue.getInstance<MyMessage>(
  MyMessage.fromJson,
  (msg) => msg.toJson(),
);
await queue.send(MyMessage('msg-id-001', 'Hello from background isolate!'));
```

---

## 🧼 Clean Up

```dart
await queue.clearAll();
```

---

## 📦 Full Example

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final queue = await PersistentQueue.getInstance<MyMessage>(
    MyMessage.fromJson,
    (msg) => msg.toJson(),
  );
  queue.bindUIIsolate();
  queue.stream.listen((msg) async {
    print("UI Isolate received: \${msg.payload}");
    await queue.ack(msg.id);
  });

  Isolate.spawn(runBackgroundIsolate, null);

  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('PersistentQueue Example')))));
}

void runBackgroundIsolate(_) async {
  final queue = await PersistentQueue.getInstance<MyMessage>(
    MyMessage.fromJson,
    (msg) => msg.toJson(),
  );

  await queue.send(MyMessage('msg-id-\${DateTime.now().millisecondsSinceEpoch}', 'Hello from background isolate!'));
}
```

---

## 📚 Related

* [IsolateNameServer](https://api.flutter.dev/flutter/dart-isolate/IsolateNameServer-class.html)
* [SharedPreferences](https://pub.dev/packages/shared_preferences)

---

## 📄 License

MIT

## 👷 TODO

- [ ] Add support for desktop platforms via alternative storage
- [ ] Add tests for isolate communication reliability
