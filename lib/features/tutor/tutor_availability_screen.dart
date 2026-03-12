import 'package:flutter/material.dart';

import '../../constants/availability_constants.dart';
import '../../repositories/tutors_repository.dart';

class TutorAvailabilityScreen extends StatefulWidget {
  final String tutorId;

  const TutorAvailabilityScreen({required this.tutorId, super.key});

  @override
  State<TutorAvailabilityScreen> createState() =>
      _TutorAvailabilityScreenState();
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

      var availability = await _tutorsRepository.getTutorAvailability(
        widget.tutorId,
      );

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
        hours.sort();
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

      await _tutorsRepository.updateTutorAvailability(widget.tutorId, _availability);

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
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
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(title: const Text('Manage Availability')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.schedule, color: Color(0xFF4051B5)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Choose available hours for each day. These slots are shown to students when booking.',
                                    style: TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...daysOfWeek.map((day) => _buildDaySection(day)),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveAvailability,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4051B5),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Availability',
                          ),
                        ),
                      ),
                    ),
                  ],
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
          ElevatedButton(onPressed: _initializeAvailability, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildDaySection(String day) {
    final hours = _availability[day] ?? [];
    final dayDisplayName = dayDisplayNames[day] ?? day;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dayDisplayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${hours.length} Open',
                  style: const TextStyle(
                    color: Color(0xFF4051B5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableHours.map((hour) {
              final isSelected = hours.contains(hour);
              return _buildHourChip(day, hour, isSelected);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHourChip(String day, String hour, bool isSelected) {
    return InkWell(
      onTap: () => _toggleHour(day, hour),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4051B5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          hour,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
