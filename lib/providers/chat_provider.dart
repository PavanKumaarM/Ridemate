import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/repositories/chat_repository.dart';


final chatRepositoryProvider =
    Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatProvider =
    StateNotifierProvider<ChatNotifier, bool>((ref) {
  return ChatNotifier(ref.read(chatRepositoryProvider));
});

class ChatNotifier extends StateNotifier<bool> {
  final ChatRepository repository;

  ChatNotifier(this.repository) : super(false);

  Future<void> sendMessage(Map<String, dynamic> data) async {
    state = true;

    await repository.sendMessage(data);

    state = false;
  }
  Future<void> getMessages(String tripId) async {
    state = true;

    await repository.getMessages(tripId);

    state = false;
  }
  
}
