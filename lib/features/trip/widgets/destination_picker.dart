import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../../core/services/location_search_service.dart';

class DestinationPicker extends StatefulWidget {

  final String label;
  final Function(String, double, double) onSelected;
  final Color iconColor;

  const DestinationPicker({
    super.key,
    required this.label,
    required this.onSelected,
    required this.iconColor,
  });

  @override
  State<DestinationPicker> createState() => _DestinationPickerState();
}

class _DestinationPickerState extends State<DestinationPicker> {

  @override
  Widget build(BuildContext context) {

    return TypeAheadField<Map<String, dynamic>>(
      suggestionsCallback: (pattern) async {
        if (pattern.length < 3) return [];
        try {
          return await LocationSearchService.searchPlaces(pattern);
        } catch (e) {
          debugPrint('Error searching places: $e');
          return [];
        }
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          leading: Icon(Icons.location_on, color: widget.iconColor),
          title: Text(suggestion['display_name'] ?? ''),
          subtitle: Text(
            '${suggestion['lat'] ?? ''}, ${suggestion['lon'] ?? ''}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
      onSelected: (suggestion) {
        final displayName = suggestion['display_name'] ?? '';
        final lat = double.tryParse(suggestion['lat']?.toString() ?? '0') ?? 0.0;
        final lon = double.tryParse(suggestion['lon']?.toString() ?? '0') ?? 0.0;

        widget.onSelected(displayName, lat, lon);
      },
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on, color: widget.iconColor),
          ),
        );
      },
      hideOnEmpty: true,
      hideOnLoading: false,
      debounceDuration: const Duration(milliseconds: 500),
    );
  }
}
