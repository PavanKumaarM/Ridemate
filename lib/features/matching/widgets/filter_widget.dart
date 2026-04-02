import 'package:flutter/material.dart';

class FilterWidget extends StatefulWidget {

  const FilterWidget({super.key});

  @override
  State<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {

  bool cheapest = false;
  bool earliest = false;

  @override
  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(
          "Filters",
          style: TextStyle(
            fontWeight: FontWeight.bold
          ),
        ),

        Row(
          children: [

            Checkbox(
              value: cheapest,
              onChanged: (value){
                setState(() {
                  cheapest = value!;
                });
              },
            ),

            const Text("Cheapest")

          ],
        ),

        Row(
          children: [

            Checkbox(
              value: earliest,
              onChanged: (value){
                setState(() {
                  earliest = value!;
                });
              },
            ),

            const Text("Earliest Departure")

          ],
        ),

      ],
    );
  }
}