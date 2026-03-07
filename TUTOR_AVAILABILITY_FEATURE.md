# Tutor Availability Management Feature

This document provides a comprehensive guide to the new tutor availability management feature that allows tutors to define specific available hours for each day of the week.

## Overview

This feature enables tutors to:
- Select available **specific hours** (not intervals) for each day of the week
- Store their availability in Firestore
- Manage their availability through an easy-to-use UI with checkboxes

## File Structure

### New Files Created

1. **`lib/constants/availability_constants.dart`**
   - Contains fixed list of available hours (08:00 - 19:00)
   - Contains days of the week
   - Contains day display names mapping

2. **`lib/features/tutor/tutor_availability_screen.dart`**
   - Main UI screen for managing availability
   - Displays all days of the week
   - Shows checkboxes for each available hour
   - Handles loading, saving, and error states

### Modified Files

1. **`lib/models/tutor_model.dart`**
   - Added `availability` field to store tutor's available hours
   - Added `_toAvailability()` helper method
   - Updated `toMap()` method to include availability

2. **`lib/repositories/tutors_repository.dart`**
   - Added `getTutorAvailability(String tutorId)` method
   - Added `updateTutorAvailability(String tutorId, Map<String, List<String>> availability)` method

3. **`lib/features/tutor/tutor_dashboard_screen.dart`**
   - Added import for `TutorAvailabilityScreen`
   - Added "Edit Availability" button to AppBar (calendar icon)
   - Button navigates to the availability management screen

## Firestore Structure

### Expected Document Structure

The availability is stored in the `tutors` collection under an `availability` field:

```
tutors
├── tutor_001
│   ├── name: "John Smith"
│   ├── email: "john@example.com"
│   ├── bio: "Experienced Math Tutor"
│   ├── hourlyRate: 25
│   ├── rating: 4.8
│   ├── subjects: ["Mathematics", "Calculus"]
│   ├── main: ["math"]
│   └── availability:
│       ├── monday: ["09:00", "10:00", "14:00"]
│       ├── tuesday: ["10:00", "11:00"]
│       ├── wednesday: []
│       ├── thursday: ["09:00", "10:00", "14:00", "15:00"]
│       ├── friday: ["14:00", "15:00", "16:00"]
│       ├── saturday: []
│       └── sunday: []
```

### Field Details

- **Field Type**: `Map<String, List<String>>`
- **Keys**: Day names in lowercase (`monday`, `tuesday`, ..., `sunday`)
- **Values**: List of time slots in 24-hour format (e.g., `"09:00"`, `"10:00"`)
- **Empty Days**: Days with no available hours should have an empty list `[]`

## Available Hours

Fixed list of available hours that tutors can select from:

```
08:00, 09:00, 10:00, 11:00, 12:00, 13:00, 14:00, 15:00, 16:00, 17:00, 18:00, 19:00
```

These are defined in `lib/constants/availability_constants.dart` as `availableHours`.

## API Reference

### TutorsRepository Methods

#### `getTutorAvailability(String tutorId)`

Fetches the availability for a specific tutor.

**Parameters:**
- `tutorId` (String): The document ID of the tutor in the `tutors` collection

**Returns:**
- `Future<Map<String, List<String>>>`: A map where keys are day names (lowercase) and values are lists of available hours

**Example:**
```dart
final availability = await tutorsRepository.getTutorAvailability('tutor_001');
// Result: {'monday': ['09:00', '10:00'], 'tuesday': ['14:00']}
```

**Throws:**
- `Exception`: If the document doesn't exist or there's a Firestore error

#### `updateTutorAvailability(String tutorId, Map<String, List<String>> availability)`

Updates the availability for a specific tutor.

**Parameters:**
- `tutorId` (String): The document ID of the tutor in the `tutors` collection
- `availability` (Map<String, List<String>>): The new availability mapping

**Example:**
```dart
await tutorsRepository.updateTutorAvailability(
  'tutor_001',
  {
    'monday': ['09:00', '10:00', '14:00'],
    'tuesday': ['10:00', '11:00'],
    'wednesday': [],
    'thursday': ['09:00', '10:00', '14:00', '15:00'],
    'friday': [],
    'saturday': [],
    'sunday': [],
  },
);
```

**Throws:**
- `Exception`: If the update fails

## UI Components

### TutorAvailabilityScreen

The main screen for managing availability.

**Features:**
- Displays all 7 days of the week
- Shows a grid of selectable hour chips for each day
- Displays selected hours for each day
- Loading state while fetching data
- Error handling with retry button
- Save button that updates Firestore
- Success snackbar on save

**Navigation:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TutorAvailabilityScreen(
      tutorId: 'tutor_001',
    ),
  ),
);
```

## Usage Examples

### Example 1: Navigate to Availability Screen

```dart
// From the Tutor Dashboard, click the calendar icon in the AppBar
// or programmatically:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TutorAvailabilityScreen(
      tutorId: tutorId,
    ),
  ),
);
```

### Example 2: Fetch Availability Programmatically

```dart
final tutorsRepository = TutorsRepository();
final availability = await tutorsRepository.getTutorAvailability('tutor_001');

print(availability['monday']); // ['09:00', '10:00', '14:00']
print(availability['tuesday']); // ['10:00', '11:00']
```

### Example 3: Update Availability Programmatically

```dart
final tutorsRepository = TutorsRepository();

final newAvailability = {
  'monday': ['09:00', '10:00', '14:00'],
  'tuesday': ['10:00', '11:00'],
  'wednesday': [],
  'thursday': ['09:00', '10:00', '14:00', '15:00'],
  'friday': ['14:00', '15:00', '16:00'],
  'saturday': [],
  'sunday': [],
};

await tutorsRepository.updateTutorAvailability('tutor_001', newAvailability);
```

## Testing

### Manual Testing Steps

1. **Start the app and navigate to Tutor Dashboard**
   - Sign in as a tutor

2. **Click the calendar icon in the AppBar**
   - You should be navigated to the TutorAvailabilityScreen

3. **Test Loading Data**
   - The screen should load the tutor's current availability
   - If no availability is set, all hours should be unselected

4. **Test Selecting Hours**
   - Click on hour chips to toggle selection
   - Selected chips should show in the primary color
   - The "Selected: XX:XX, YY:YY" text should update

5. **Test Saving**
   - Select some hours for different days
   - Click "Save Availability"
   - You should see a success message
   - Screen should pop back to dashboard

6. **Verify Data Persistence**
   - Return to the availability screen
   - The previously selected hours should be restored

7. **Test Error Handling**
   - Try saving without network connection (if applicable)
   - Verify error message is displayed
   - Click "Retry" or go back and try again

### Firebase Testing

1. **Verify Firestore Structure**
   - Open Firebase Console
   - Navigate to Firestore > Database
   - Find the tutor document
   - Check the `availability` field contains the expected structure

2. **Example Expected Data:**
   ```json
   {
     "monday": ["09:00", "10:00", "14:00"],
     "tuesday": ["10:00", "11:00"],
     "wednesday": [],
     "thursday": [],
     "friday": [],
     "saturday": [],
     "sunday": []
   }
   ```

## Integration Points

### Dashboard Integration
The feature is integrated into the Tutor Dashboard through a calendar icon button in the AppBar. Clicking this button navigates to the availability management screen.

### Future Integration Points
1. **Booking System**: Use availability data to validate booking slots
2. **Session Scheduling**: Prevent bookings outside available hours
3. **Availability Display**: Show available tutors based on selected time slots

## Constants Reference

### `lib/constants/availability_constants.dart`

```dart
// Available hours
const List<String> availableHours = [
  '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', 
  '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
];

// Days of the week
const List<String> daysOfWeek = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];

// Display names for days
const Map<String, String> dayDisplayNames = {
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};
```

## Error Handling

The feature handles the following error scenarios:

1. **Failed to load availability**
   - Shows error message with retry button
   - Allows user to retry loading

2. **Failed to save availability**
   - Shows error message in snackbar
   - Keeps data in memory for retry
   - User can close screen and try again

3. **Missing tutor document**
   - Returns empty availability map
   - Allows user to set availability

## State Management

The `TutorAvailabilityScreen` uses `StatefulWidget` with local state management:

- `_availability`: Current availability map
- `_isLoading`: Loading state while fetching data
- `_isSaving`: Saving state while updating Firestore
- `_errorMessage`: Error message if any operation fails

## Performance Considerations

1. **Data Loading**: Availability is fetched once on screen initialization
2. **Local Updates**: Hour selections are handled locally without Firestore updates
3. **Batch Update**: All changes are saved in a single Firestore update
4. **Ui Responsiveness**: Loading and saving states provide user feedback

## Migration Notes

If migrating from `weeklyAvailability` to `availability`:
1. Both fields are supported in the Tutor model
2. New code should use the `availability` field
3. Old `weeklyAvailability` field remains for backward compatibility
4. Consider migrating existing data in a separate task
