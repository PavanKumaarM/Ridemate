import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/repositories/payment_repository.dart';

final paymentRepositoryProvider =
    Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, bool>((ref) {
  return PaymentNotifier(ref.read(paymentRepositoryProvider));
});

class PaymentNotifier extends StateNotifier<bool> {
  final PaymentRepository repository;

  PaymentNotifier(this.repository) : super(false);

  Future<void> makePayment(Map<String, dynamic> data) async {
    state = true;

    await repository.makePayment(data);

    state = false;
  }
}