import 'package:flutter/material.dart';

class FareSummaryWidget extends StatelessWidget {

  final double fare;

  const FareSummaryWidget({
    super.key,
    required this.fare,
  });

  @override
  Widget build(BuildContext context) {

    const double platformFee = 10;

    final double total = fare + platformFee;

    return Card(

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Fare Summary",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ride Fare"),
                Text("₹$fare"),
              ],
            ),

            const SizedBox(height: 6),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Platform Fee"),
                Text("₹10"),
              ],
            ),

            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "₹$total",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )

          ],
        ),
      ),
    );
  }
}