import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/payment_provider.dart';
import '../widgets/fare_summary_widget.dart';

class PaymentScreen extends ConsumerWidget {

  final String tripId;
  final String payerId;
  final double fare;

  const PaymentScreen({
    super.key,
    required this.tripId,
    required this.payerId,
    required this.fare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final loading = ref.watch(paymentProvider);

    Future<void> makePayment() async {

      await ref.read(paymentProvider.notifier).makePayment({

        "trip_id": tripId,
        "payer_id": payerId,
        "amount": fare,
        "status": "completed"

      });

      if(context.mounted){
        Navigator.pushReplacementNamed(
          context,
          "/paymentSuccess"
        );
      }
    }

    return Scaffold(

      appBar: AppBar(
        title: const Text("Payment"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            FareSummaryWidget(fare: fare),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(

                onPressed: loading ? null : makePayment,

                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Pay Now"),

              ),
            )

          ],
        ),
      ),
    );
  }
}