# MedShift Thailand - Architecture Documentation

## 📐 Architecture Overview

This project follows **Clean Architecture** principles with clear separation of concerns and Provider for state management.

## 🏛️ Layered Architecture

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│  (Screens, Widgets, UI Logic)       │
├─────────────────────────────────────┤
│      State Management Layer         │
│     (Providers, Business Logic)     │
├─────────────────────────────────────┤
│         Domain Layer                │
│    (Models, Enums, Utilities)       │
├─────────────────────────────────────┤
│         Data Layer                  │
│    (API Client, Repositories)       │
└─────────────────────────────────────┘
```

## 📁 Folder Structure

### `/lib/core/`

Core functionality shared across the app.

```
core/
├── api/
│   └── api_client.dart          # Dio HTTP client with interceptors
├── constants/
│   └── app_constants.dart       # App-wide constants
├── enums/
│   └── status_enums.dart        # JobStatus & ApplicationStatus enums
└── theme/
    └── app_theme.dart           # Material Design 3 theme
```

### `/lib/models/`

Data models with JSON serialization.

```
models/
├── job_model.dart               # Job entity
├── staff_profile_model.dart     # Staff profile entity
└── transaction_model.dart       # Transaction/wallet entity
```

**Note**: Run build_runner to generate `.g.dart` files:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### `/lib/providers/`

State management using Provider pattern.

```
providers/
├── job_provider.dart            # Manages job state and operations
└── wallet_provider.dart         # Manages wallet state and transactions
```

### `/lib/screens/`

UI screens organized by feature.

```
screens/
├── home/
│   └── home_screen.dart         # Main navigation (BottomNavigationBar)
├── job_feed/
│   └── job_feed_screen.dart     # Job listing with cards
├── job_detail/
│   └── job_detail_screen.dart   # Detailed job view
├── wallet/
│   └── wallet_screen.dart       # Wallet balance & transactions
└── profile/
    └── profile_screen.dart      # Staff profile management
```

### `/lib/utils/`

Utility classes for business logic.

```
utils/
├── conflict_checker.dart        # Schedule conflict detection
└── smart_route_helper.dart      # Distance & travel time calculation
```

## 🔄 Data Flow

### 1. User Interaction Flow

```
User Tap → Screen Widget → Provider Method → API Client → Backend
                ↓                                ↓
            Update UI ← Notify Listeners ← Update State
```

### 2. State Management Flow (Provider)

```dart
// 1. User taps "Apply for Job"
onPressed: () {
  context.read<JobProvider>().applyForJob(
    jobId: job.id,
    staffId: staffId,
  );
}

// 2. Provider processes request
class JobProvider extends ChangeNotifier {
  Future<bool> applyForJob(...) async {
    // Check conflicts
    // Call API
    // Update state
    notifyListeners(); // ← Triggers UI rebuild
  }
}

// 3. UI updates automatically
Consumer<JobProvider>(
  builder: (context, jobProvider, child) {
    // UI rebuilds when notifyListeners() is called
    return ListView.builder(...);
  },
)
```

## 🎯 Core Business Logic

### 1. Waitlist System

**Implementation**: `job_model.dart`

```dart
class JobModel {
  final String? hiredStaffId;              // Currently hired staff
  final List<String> waitlistStaffIds;     // Waitlist queue

  bool get isWaitlistFull => waitlistStaffIds.length >= 10;
}
```

**Flow**:

1. Job is posted (status: `Open`)
2. Staff applies → Added to waitlist
3. Hospital reviews applications (status: `Selecting`)
4. One staff is hired (status: `Confirmed`)
5. Others remain on waitlist
6. If hired staff cancels, first in waitlist is promoted

### 2. Conflict Detection

**Implementation**: `utils/conflict_checker.dart`

```dart
static bool hasTimeConflict({
  required JobModel newJob,
  required List<JobModel> hiredJobs,
}) {
  for (final job in hiredJobs) {
    if (_isTimeOverlapping(
      newJob.startTime, newJob.endTime,
      job.startTime, job.endTime,
    )) {
      return true;
    }
  }
  return false;
}
```

**Checks**:

- ✅ New job starts during existing job
- ✅ New job ends during existing job
- ✅ New job completely contains existing job
- ✅ Exact time matches
- ✅ Optional buffer time for travel

### 3. Negative Balance System

**Implementation**: `providers/wallet_provider.dart`

```dart
Future<bool> applyCancellationPenalty({
  required String staffId,
  required String jobId,
  String? reason,
}) async {
  final penaltyAmount = -AppConstants.cancellationFee;
  final balanceAfter = _balance + penaltyAmount;

  // Balance can go negative!
  _balance = balanceAfter;
  notifyListeners();
}
```

**Features**:

- ✅ Allow negative balance
- ✅ Track penalties separately
- ✅ Calculate total earnings
- ✅ Show warning for negative balance
- ✅ Check if staff can accept new jobs

### 4. Smart Route Helper

**Implementation**: `utils/smart_route_helper.dart`

**Features**:

- Distance calculation (Haversine formula)
- Travel time estimation (configurable speed)
- Travel cost estimation
- Proximity sorting
- Acceptability checking

```dart
// Calculate distance in kilometers
final distance = SmartRouteHelper.calculateDistance(
  startLat: 13.7563, startLng: 100.5018,
  endLat: 13.7465, endLng: 100.5316,
);

// Estimate travel time (assumes 30 km/h)
final minutes = SmartRouteHelper.estimateTravelTime(
  startLat: currentLat, startLng: currentLng,
  endLat: jobLat, endLng: jobLng,
  averageSpeed: 30.0,
);

// Check if acceptable (max 2 hours)
final isOk = SmartRouteHelper.isAcceptableTravelTime(
  startLat: currentLat, startLng: currentLng,
  endLat: jobLat, endLng: jobLng,
  maxTravelMinutes: 120,
);
```

## 🎨 UI Architecture

### Theme System

**Material Design 3** with Thai font support.

```dart
// Primary Colors
primaryColor: #00796B (Teal)
secondaryColor: #004D40 (Dark Teal)

// Fonts
Headings: Prompt (Thai support)
Body: Inter (Modern, clean)
```

**Status Colors**:

```dart
jobStatusColors = {
  'Open': Blue,
  'Selecting': Orange,
  'Confirmed': Green,
  'InProgress': Teal,
  'Completed': Light Green,
  'Cancelled': Red,
}
```

### Screen Architecture

Each screen follows this pattern:

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch data after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MyProvider>().fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Screen')),
      body: Consumer<MyProvider>(
        builder: (context, provider, child) {
          // Handle loading state
          if (provider.isLoading) {
            return CircularProgressIndicator();
          }

          // Handle error state
          if (provider.error != null) {
            return ErrorWidget(error: provider.error);
          }

          // Render data
          return ListView.builder(...);
        },
      ),
    );
  }
}
```

## 🔐 Security Considerations

### Current Implementation

- ✅ API client with interceptors
- ✅ Error handling
- ✅ Input validation (models)

### To Implement (Production)

- 🔲 Authentication tokens
- 🔲 Token refresh logic
- 🔲 Secure storage (flutter_secure_storage)
- 🔲 Biometric authentication
- 🔲 API key encryption
- 🔲 Certificate pinning

## 📊 State Management Deep Dive

### Why Provider?

1. **Official Flutter recommendation**
2. **Simple and intuitive**
3. **Good performance**
4. **Easy testing**
5. **No boilerplate code**

### Provider Setup

```dart
// main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => JobProvider(apiClient),
    ),
    ChangeNotifierProvider(
      create: (_) => WalletProvider(apiClient),
    ),
  ],
  child: MaterialApp(...),
)
```

### Provider Pattern

```dart
class MyProvider extends ChangeNotifier {
  // Private state
  List<Job> _jobs = [];
  bool _isLoading = false;
  String? _error;

  // Public getters
  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Methods that modify state
  Future<void> fetchJobs() async {
    _isLoading = true;
    notifyListeners(); // ← Update UI

    try {
      _jobs = await api.getJobs();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners(); // ← Update UI
  }
}
```

## 🧪 Testing Strategy

### Unit Tests

```dart
test('ConflictChecker detects overlapping jobs', () {
  final newJob = JobModel(...);
  final existingJobs = [JobModel(...)];

  final hasConflict = ConflictChecker.hasTimeConflict(
    newJob: newJob,
    hiredJobs: existingJobs,
  );

  expect(hasConflict, true);
});
```

### Widget Tests

```dart
testWidgets('JobCard displays job information', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: JobCard(job: mockJob),
    ),
  );

  expect(find.text(mockJob.title), findsOneWidget);
  expect(find.text(mockJob.hospitalName), findsOneWidget);
});
```

## 🚀 Performance Optimizations

1. **Lazy Loading**: Use `ListView.builder` for long lists
2. **Image Caching**: Use `cached_network_image` for profile pictures
3. **Pagination**: Load jobs in batches
4. **Debouncing**: Debounce search inputs
5. **Selective Rebuilds**: Use `Consumer` widget strategically

## 📱 Platform Considerations

### Android

- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)

### iOS

- Minimum version: iOS 12.0
- Target version: iOS 17.0

## 🔄 Future Enhancements

1. **Repository Pattern**: Add repository layer for better separation
2. **Dependency Injection**: Use get_it for DI
3. **Bloc/Riverpod**: Consider migration for larger scale
4. **Offline Support**: Add local database (Hive/Drift)
5. **Analytics**: Add Firebase Analytics
6. **Crash Reporting**: Add Crashlytics

---

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Material Design 3](https://m3.material.io/)

---

**Version**: 1.0.0  
**Last Updated**: May 2026  
**Author**: Senior Flutter Development Team
