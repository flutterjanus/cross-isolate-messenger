import 'package:flutter_test/flutter_test.dart';

import 'package:cross_isolate_messenger/cross_isolate_messenger.dart';

void main() async {
  final queue = CrossIsolateQueue<Map<String, String>>.getInstance(
    'chat_queue',
  );
  await queue.initialize();

  queue.stream.listen((msg) {
    print('Received: $msg');
  });

  await CrossIsolateQueue.send('chat_queue', {
    'id': 'msg-1',
    'content': 'Hello from another isolate!',
  });
}
