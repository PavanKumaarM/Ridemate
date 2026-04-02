import 'package:flutter/material.dart';

class StatsWidget extends StatelessWidget {

  const StatsWidget({super.key});

  @override
  Widget build(BuildContext context) {

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [

        _statCard("Rides", "12", Icons.directions_car),

        _statCard("Rating", "4.8", Icons.star),

        _statCard("Earnings", "₹1200", Icons.currency_rupee),

      ],
    );
  }

  Widget _statCard(String title,String value,IconData icon){

    return Expanded(
      child: Card(

        child: Padding(
          padding: const EdgeInsets.all(12),

          child: Column(

            children: [

              Icon(icon,color: Colors.blue),

              const SizedBox(height:6),

              Text(
                value,
                style: const TextStyle(
                  fontSize:18,
                  fontWeight: FontWeight.bold
                ),
              ),

              Text(title)

            ],
          ),
        ),
      ),
    );
  }
}