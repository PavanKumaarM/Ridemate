import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider =
    StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<bool> {
  final AuthRepository repository;

  AuthNotifier(this.repository) : super(false);

  Future<void> login(String phone) async {
    await repository.login(phone);
  }

  void setAuthenticated() {
    state = true;
  }

  void logout() {
    state = false;
  }
}