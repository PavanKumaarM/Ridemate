import 'package:flutter/material.dart';

class FareCalculator extends StatefulWidget {
  final Function(double) onFareChanged;
  final double distanceKm;

  const FareCalculator({
    super.key,
    required this.onFareChanged,
    this.distanceKm = 0,
  });

  @override
  State<FareCalculator> createState() => _FareCalculatorState();
}

class _FareCalculatorState extends State<FareCalculator> {
  double adjustment = 0;

  double get baseFare => widget.distanceKm > 0 ? (widget.distanceKm / 12) * 40 : 0;
  double get totalFare => baseFare + adjustment;

  @override
  void didUpdateWidget(FareCalculator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distanceKm != widget.distanceKm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFareChanged(totalFare);
      });
    }
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 12),
              const Text(
                'Estimated Fare',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${totalFare.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          if (widget.distanceKm > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Distance: ${widget.distanceKm.toStringAsFixed(1)} km • Base: ₹${baseFare.toInt()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFDBEAFE),
              thumbColor: const Color(0xFF2563EB),
              overlayColor: const Color(0xFF2563EB).withOpacity(0.1),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: adjustment,
              min: 0,
              max: 50,
              divisions: 10,
              onChanged: widget.distanceKm > 0
                  ? (value) {
                      setState(() => adjustment = value);
                      widget.onFareChanged(totalFare);
                    }
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('+₹0', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              Text('+₹50', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}