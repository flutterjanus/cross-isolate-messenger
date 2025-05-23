import 'package:flutter_test/flutter_test.dart';

import 'package:cross_isolate_messenger/cross_isolate_messenger.dart';

class MyMessage {
  final String id;
  final String payload;
  MyMessage(this.id, this.payload);

  Map<String, dynamic> toJson() => {'id': id, 'payload': payload};
  static MyMessage fromJson(Map<String, dynamic> json) =>
      MyMessage(json['id'], json['payload']);
}

void main() async {
  final queue = await PersistentQueue.getInstance<MyMessage>(
    MyMessage.fromJson,
    (msg) => msg.toJson(),
  );

  queue.stream.listen((msg) {
    print('Received: $msg');
  });

}
