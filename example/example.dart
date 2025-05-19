import 'package:cross_isolate_messenger/cross_isolate_messenger.dart';

void main() async {
  final queue = CrossIsolateQueue<Map<String, dynamic>>.getInstance('test');
  await queue.initialize();

  queue.stream.listen((msg) {
    print('Received: $msg');
  });

  await CrossIsolateQueue.send('test', {
    'id': 'msg-1',
    'text': 'Hello world',
  });
}
