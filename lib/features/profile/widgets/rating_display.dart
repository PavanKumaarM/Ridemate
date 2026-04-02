import 'package:flutter/material.dart';

class RatingDisplay extends StatelessWidget {

  final double rating;

  const RatingDisplay({
    super.key,
    required this.rating
  });

  @override
  Widget build(BuildContext context) {

    return Row(

      children: [

        const Icon(Icons.star,color: Colors.orange),

        const SizedBox(width:6),

        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(width:6),

        const Text("Rating")

      ],
    );
  }
}