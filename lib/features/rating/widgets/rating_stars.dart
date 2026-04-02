import 'package:flutter/material.dart';

class RatingStars extends StatefulWidget {

  final Function(int) onChanged;

  const RatingStars({
    super.key,
    required this.onChanged
  });

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars> {

  int rating = 5;

  void updateRating(int value){

    setState(() {
      rating = value;
    });

    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {

    return Row(

      mainAxisAlignment: MainAxisAlignment.center,

      children: List.generate(5, (index){

        final starIndex = index + 1;

        return IconButton(

          icon: Icon(
            starIndex <= rating
                ? Icons.star
                : Icons.star_border,
            color: Colors.orange,
            size: 36,
          ),

          onPressed: (){
            updateRating(starIndex);
          },

        );
      }),
    );
  }
}