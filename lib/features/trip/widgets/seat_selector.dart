import 'package:flutter/material.dart';

class SeatSelector extends StatefulWidget {
  final Function(int) onChanged;

  const SeatSelector({super.key, required this.onChanged});

  @override
  State<SeatSelector> createState() => _SeatSelectorState();
}

class _SeatSelectorState extends State<SeatSelector> {
  int seats = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.event_seat, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 12),
              const Text(
                'Available Seats',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _CounterButton(
                icon: Icons.remove,
                onTap: () {
                  if (seats > 1) {
                    setState(() => seats--);
                    widget.onChanged(seats);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$seats',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              _CounterButton(
                icon: Icons.add,
                onTap: () {
                  setState(() => seats++);
                  widget.onChanged(seats);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
      ),
    );
  }
}