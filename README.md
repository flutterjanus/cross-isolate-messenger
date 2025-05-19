# 📨 Cross Isolate Messenger

**Cross Isolate Messenger** is a lightweight Dart utility for message passing and persistence across multiple Dart isolates in Flutter applications.

It uses `SharedPreferences` under the hood for durability, making it ideal for native platforms (Android, iOS, macOS) where isolates might need to resume processing messages after being restarted or delayed.

---

## ✨ Features

- 🔄 **Message persistence**: Messages are stored in `SharedPreferences` until acknowledged.
- 🚦 **Isolate communication**: Broadcast messages across Dart isolates using named channels.
- 🧠 **LRU cache-based deduplication**: Prevents duplicate processing across restarts or replay.
- 🧱 **Generic and extensible**: Supports custom classes via decoders and multiple message streams via unique `portName`s.

---

## 🧩 Requirements

> ✅ **Native platforms only** – This package relies on `SharedPreferences`, so it will not function on web or unsupported platforms like Windows or Linux (without `SharedPreferences` support).

---

## 🚀 Installation

```yaml
dependencies:
  cross_isolate_messenger: 1.0.0
````

Then include your cross isolate queue code in your project.

---

## 🛠 Usage

### 1. Create an instance (per channel)

```dart
final queue = CrossIsolateQueue<Map<String, dynamic>>.getInstance('chat_channel');
await queue.initialize();

queue.stream.listen((msg) {
  print('Received message: $msg');
});
```

### 2. Send a message from another isolate

```dart
await CrossIsolateQueue.send('chat_channel', {
  'id': 'message-001',
  'content': 'Hello from another isolate!',
});
```

### 3. Acknowledge a message

```dart
await queue.ack('message-001');
```

---

## 🔁 Custom Message Types

Define a class and a decoder:

```dart
class MyMessage {
  final String id;
  final String content;

  MyMessage(this.id, this.content);

  factory MyMessage.fromJson(Map<String, dynamic> json) =>
      MyMessage(json['id'], json['content']);
}
```

Use the decoder when creating the queue:

```dart
final customQueue = CrossIsolateQueue<MyMessage>.getInstance(
  'custom_channel',
  decoder: (json) => MyMessage.fromJson(json),
);
await customQueue.initialize();
```

---

## 🧼 Clean Up

```dart
await queue.dispose();
```

---

## ⚠ Limitations

* ❌ Not supported on **web** or **desktop platforms** without `SharedPreferences`.
* 📦 Not yet packaged as a Flutter/Dart plugin (you’ll need to copy the utility code).
* 🧪 Currently single-process only. For true multi-process communication, use platform channels.

---

## 📚 Related

* [IsolateNameServer](https://api.flutter.dev/flutter/dart-isolate/IsolateNameServer-class.html)
* [SharedPreferences](https://pub.dev/packages/shared_preferences)

---

## 📄 License

MIT or your preferred license.

---

## 👷 TODO

* [ ] Add fallback for unsupported platforms
* [ ] Add testing harness for isolate message passing

---

> Developed for native Flutter apps that require persistent, simple isolate communication.

```

---

Let me know if you’d like a `pubspec.yaml`, example project structure, or a GitHub-ready version with badges!
