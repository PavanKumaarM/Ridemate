import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/rating_provider.dart';
import '../widgets/rating_stars.dart';

class RatingScreen extends ConsumerStatefulWidget {

  final String tripId;
  final String fromUser;
  final String toUser;

  const RatingScreen({
    super.key,
    required this.tripId,
    required this.fromUser,
    required this.toUser,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {

  int rating = 5;
  final TextEditingController reviewController =
      TextEditingController();

  Future<void> submitRating() async {

    await ref.read(ratingProvider.notifier).submitRating({

      "trip_id": widget.tripId,
      "from_user": widget.fromUser,
      "to_user": widget.toUser,
      "rating": rating,
      "review": reviewController.text

    });

    if(context.mounted){

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rating submitted"))
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {

    final loading = ref.watch(ratingProvider);

    return Scaffold(

      appBar: AppBar(
        title: const Text("Rate Your Ride"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "How was your trip?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            RatingStars(
              onChanged: (value){
                rating = value;
              },
            ),

            const SizedBox(height: 20),

            TextField(

              controller: reviewController,

              maxLines: 3,

              decoration: const InputDecoration(
                labelText: "Write a review",
                border: OutlineInputBorder(),
              ),

            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(

                onPressed: loading ? null : submitRating,

                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Submit Rating"),

              ),
            )

          ],
        ),
      ),
    );
  }
}