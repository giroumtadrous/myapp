# Tutor Availability Feature - Quick Start Guide

## 🎯 What's New?

Tutors can now manage their **specific available hours** for each day of the week through an intuitive UI.

## 📍 How to Access

1. **Sign in as a tutor** to the mobile app
2. **Go to Tutor Dashboard**
3. **Click the calendar icon** in the top-right corner of the AppBar
4. You'll see the **TutorAvailabilityScreen**

## 🖼️ UI Preview

### Main Screen
```
┌─────────────────────────────────────────┐
│  Edit Availability                  📅  │  ← Calendar icon
├─────────────────────────────────────────┤
│                                          │
│  Select available hours for each day    │
│                                          │
│  Monday                                  │
│  ☑ 08:00  ☑ 09:00  ☐ 10:00  ☑ 14:00  │
│  Selected: 08:00, 09:00, 14:00           │
│  ─────────────────────────────────────  │
│                                          │
│  Tuesday                                 │
│  ☐ 08:00  ☑ 09:00  ☑ 10:00  ☐ 14:00  │
│  Selected: 09:00, 10:00                  │
│  ─────────────────────────────────────  │
│                                          │
│  [... Wed-Fri ...]                       │
│                                          │
│  Saturday                                │
│  ☐ 08:00  ☐ 09:00  ☐ 10:00  ☐ 14:00  │
│  ─────────────────────────────────────  │
│                                          │
│  Sunday                                  │
│  ☐ 08:00  ☐ 09:00  ☐ 10:00  ☐ 14:00  │
│  ─────────────────────────────────────  │
│                                          │
│         [ Save Availability ]            │
│                                          │
└─────────────────────────────────────────┘
```

## ✨ Features

✅ **Simple UI**: Click hour chips to toggle availability
✅ **Visual Feedback**: Selected hours highlighted in blue
✅ **Show Summary**: "Selected: XX:XX, YY:YY" for each day
✅ **Error Handling**: Graceful error messages with retry
✅ **Auto Save**: One-tap save to Firestore
✅ **Instant Feedback**: Success message after saving

## 📊 Available Hours

Fixed list of bookable hours:
- **08:00** - 09:00 - 10:00 - 11:00 - 12:00 - 13:00
- **14:00** - 15:00 - 16:00 - 17:00 - 18:00 - 19:00

## 💾 Data Storage

Availability is saved in Firebase Firestore:

```
tutors/
  └── tutor_001/
      └── availability: {
            "monday": ["09:00", "10:00", "14:00"],
            "tuesday": ["10:00", "11:00"],
            "wednesday": [],
            ...
          }
```

Each day stores an array of available time slots.

## 🔄 Complete User Flow

```
┌──────────┐
│ Dashboard│
└────┬─────┘
     │ Click calendar icon
     ▼
┌─────────────────────┐
│ Load Availability   │
│ from Firestore      │
└────┬────────────────┘
     │ Pre-select saved hours
     ▼
┌─────────────────────┐
│ Show Screen with    │
│ all days & hours    │
└────┬────────────────┘
     │ User toggles hours
     ▼
┌─────────────────────┐
│ Update Local State  │
│ in real-time        │
└────┬────────────────┘
     │ User clicks Save
     ▼
┌─────────────────────┐
│ Send to Firestore   │
│ Update availability │
└────┬────────────────┘
     │ Success!
     ▼
┌──────────┐
│ Pop Back │
│ Dashboard│
└──────────┘
```

## 📋 Implementation Details

### Files Created
- `lib/constants/availability_constants.dart` - Hour & day constants
- `lib/features/tutor/tutor_availability_screen.dart` - Main UI screen

### Files Modified
- `lib/models/tutor_model.dart` - Added `availability` field
- `lib/repositories/tutors_repository.dart` - Added 2 repo methods
- `lib/features/tutor/tutor_dashboard_screen.dart` - Added navigation

### API Methods

**Get Availability:**
```dart
final availability = await TutorsRepository()
    .getTutorAvailability('tutor_001');
// Returns: {'monday': ['09:00', '10:00'], 'tuesday': ['14:00']}
```

**Update Availability:**
```dart
await TutorsRepository().updateTutorAvailability(
  'tutor_001',
  {
    'monday': ['09:00', '10:00', '14:00'],
    'tuesday': ['10:00', '11:00'],
    // ... other days
  },
);
```

## 🧪 Quick Test

1. **Open the app** and sign in as tutor
2. **Navigate to Dashboard**
3. **Click calendar icon**
4. **Select a few hours** for Monday and Tuesday
5. **Click "Save Availability"**
6. **Check Firestore Console**:
   - Go to Firebase > Firestore
   - Find tutors collection
   - Open your tutor document
   - See `availability` field with your selections
7. **Go back to screen**
   - Hours should still be selected
   - Confirming persistence ✓

## 📚 Documentation

For detailed documentation, see:
- [TUTOR_AVAILABILITY_FEATURE.md](../TUTOR_AVAILABILITY_FEATURE.md)
- [IMPLEMENTATION_SUMMARY.md](../IMPLEMENTATION_SUMMARY.md)

## 🚀 Ready to Use!

The feature is fully implemented and ready for:
1. Testing by QA team
2. Integration with booking system
3. Deployment to production

---

**Feature Status**: ✅ Complete
**Last Updated**: March 7, 2026
**Version**: 1.0
