import 'package:flutter/material.dart';

import '../../constants/availability_constants.dart';
import '../../repositories/tutors_repository.dart';

class TutorAvailabilityScreen extends StatefulWidget {
  final String tutorId;

  const TutorAvailabilityScreen({
    required this.tutorId,
    super.key,
  });

  @override
  State<TutorAvailabilityScreen> createState() => _TutorAvailabilityScreenState();
}

class _TutorAvailabilityScreenState extends State<TutorAvailabilityScreen> {
  final _tutorsRepository = TutorsRepository();
  late Map<String, List<String>> _availability;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAvailability();
  }

  Future<void> _initializeAvailability() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Fetch current availability from weeklyAvailability field
      var availability = await _tutorsRepository.getTutorAvailability(widget.tutorId);
      debugPrint(
        'TutorAvailabilityScreen: loaded weeklyAvailability for ${widget.tutorId}: $availability',
      );

      // Initialize all days with empty list if not present
      // This ensures all days are represented in the map
      for (final day in daysOfWeek) {
        if (!availability.containsKey(day)) {
          availability[day] = [];
        }
      }

      setState(() {
        _availability = availability;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load availability: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleHour(String day, String hour) {
    setState(() {
      final hours = _availability[day] ?? [];
      if (hours.contains(hour)) {
        hours.remove(hour);
      } else {
        hours.add(hour);
        hours.sort(); // Keep hours sorted
      }
      _availability[day] = hours;
    });
  }

  Future<void> _saveAvailability() async {
    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      // Update weeklyAvailability field in Firestore
      await _tutorsRepository.updateTutorAvailability(
        widget.tutorId,
        _availability,
      );
      debugPrint(
        'TutorAvailabilityScreen: saved weeklyAvailability for ${widget.tutorId}: $_availability',
      );

      setState(() {
        _isSaving = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        // Optionally pop after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save availability: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Availability'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Select available hours for each day',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...daysOfWeek.map((day) => _buildDaySection(day)),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveAvailability,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save Availability'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeAvailability,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(String day) {
    final hours = _availability[day] ?? [];
    final dayDisplayName = dayDisplayNames[day] ?? day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayDisplayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableHours.map((hour) {
              final isSelected = hours.contains(hour);
              return _buildHourChip(day, hour, isSelected);
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (hours.isNotEmpty)
            Text(
              'Selected: ${hours.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          Divider(color: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildHourChip(String day, String hour, bool isSelected) {
    return FilterChip(
      label: Text(hour),
      selected: isSelected,
      onSelected: (_) => _toggleHour(day, hour),
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
