# MedShift Thailand 🏥

A Medical Staffing Marketplace mobile application built with Flutter, designed for Thailand's healthcare sector. The app implements a waitlist model where medical staff can apply for jobs and be placed on a waitlist if the position is filled.

## 🎯 Features

- **Waitlist System**: Smart job application with automatic waitlist management
- **Conflict Detection**: Prevents scheduling conflicts with existing jobs
- **Wallet Management**: Handles payments and negative balance (penalties)
- **Smart Route Helper**: Calculates travel time and distance to job locations
- **Material Design 3**: Modern, beautiful UI with Thai font support
- **Development Mode**: Bypass login for testing without API connection

## 🚀 Quick Start (Development Mode)

For development and testing **without API**:

1. **Bypass Login is enabled by default** in `lib/core/constants/app_constants.dart`:
   ```dart
   static const bool isDevelopmentMode = true;
   static const bool bypassLogin = true;
   ```

2. **Run the app**:
   ```bash
   flutter run
   flutter run -d chrome  # For web
   ```

3. **Login with any credentials** - no need for real account!

📖 See [DEVELOPMENT_CONFIG.md](DEVELOPMENT_CONFIG.md) for detailed development mode documentation.

## 🏗️ Architecture

This project follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── core/
│   ├── api/          # API client (Dio)
│   ├── constants/    # App constants
│   ├── enums/        # Status enums
│   └── theme/        # Material Design 3 theme
├── models/           # Data models with JSON serialization
├── providers/        # State management (Provider)
├── screens/          # UI screens
│   ├── home/
│   ├── job_feed/
│   ├── job_detail/
│   ├── wallet/
│   └── profile/
└── utils/            # Utility classes
```

## �️ Getting Started (Production Setup)

### Prerequisites

- Flutter SDK (3.38.0 or higher)
- Dart SDK (3.10.0 or higher)
- Android Studio / VS Code
- iOS Simulator / Android Emulator / Chrome

### Installation

1. **Clone the repository**

   ```bash
   cd d:\Git\flutter\nurse
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run              # Auto-select device
   flutter run -d chrome    # Web
   flutter run -d windows   # Windows desktop
   ```

### 🧪 Development vs Production

**Development Mode (Current):**
- ✅ Bypass login enabled
- ✅ No API required
- ✅ Mock user data
- ✅ Quick testing

**Production Mode:**
Set in `lib/core/constants/app_constants.dart`:
```dart
static const bool isDevelopmentMode = false;
static const bool bypassLogin = false;
```

## 📦 Dependencies

### Core

- `provider: ^6.1.1` - State management
- `dio: ^5.4.0` - HTTP client

### UI

- `google_fonts: ^6.1.0` - Google Fonts (Prompt & Inter)
- `intl: ^0.18.1` - Internationalization

### Location

- `geolocator: ^10.1.0` - Location services
- `google_maps_flutter: ^2.5.0` - Map integration

### Storage

- `shared_preferences: ^2.2.2` - Local storage
- `uuid: ^4.2.2` - UUID generation

### Development

- `flutter_lints: ^3.0.1` - Linting rules

**Note**: This project uses **manual JSON serialization** (no code generation required).

## 🎨 Theme

### Colors

- **Primary**: #00796B (Teal)
- **Secondary**: #004D40 (Dark Teal)
- **Accent**: #26A69A

### Fonts

- **Headings**: Prompt (Thai support)
- **Body**: Inter (Clean, modern)

## 📊 Business Logic

### Job Status Flow

```
Open → Selecting → Confirmed → InProgress → Completed
                              ↓
                          Cancelled
```

### Application Status

- **Pending**: Application submitted, awaiting review
- **Hired**: Selected for the job
- **Waitlist**: Job filled, placed on waitlist
- **Withdrawn**: Staff withdrew application
- **NoShow**: Staff didn't show up

### Wallet System

#### Negative Balance Handling

When a staff member cancels a hired job:

1. Cancellation fee (50 THB) is applied
2. Balance can go negative
3. Staff must complete jobs to clear negative balance
4. Earnings from completed jobs offset the negative balance

Example:

```dart
Initial Balance: 100 THB
Cancel Job: -50 THB penalty
New Balance: 50 THB

Complete Job: +500 THB
Final Balance: 550 THB
```

### Conflict Checker

The conflict checker prevents scheduling overlaps:

```dart
// Check if new job conflicts with hired jobs
final hasConflict = ConflictChecker.hasTimeConflict(
  newJob: newJob,
  hiredJobs: myHiredJobs,
);

// Check with buffer time (30 min for travel)
final hasConflictWithBuffer = ConflictChecker.hasConflictWithBuffer(
  newJob: newJob,
  hiredJobs: myHiredJobs,
  bufferTime: Duration(minutes: 30),
);
```

### Smart Route Helper

Calculate travel time and distance:

```dart
// Calculate distance
final distance = SmartRouteHelper.calculateDistance(
  startLat: 13.7563,
  startLng: 100.5018,
  endLat: 13.7465,
  endLng: 100.5316,
);

// Estimate travel time (assumes 30 km/h in Bangkok traffic)
final travelTime = SmartRouteHelper.estimateTravelTime(
  startLat: currentLat,
  startLng: currentLng,
  endLat: jobLat,
  endLng: jobLng,
);

// Check if travel is acceptable (max 2 hours)
final isAcceptable = SmartRouteHelper.isAcceptableTravelTime(
  startLat: currentLat,
  startLng: currentLng,
  endLat: jobLat,
  endLng: jobLng,
  maxTravelMinutes: 120,
);
```

## 🔧 Configuration

### Development Mode (Bypass Login)

Enable/disable in `lib/core/constants/app_constants.dart`:

```dart
// Development Mode - Bypass Login (ไม่ต้องต่อ API)
static const bool isDevelopmentMode = true;  // Set false for production
static const bool bypassLogin = true;         // Set false for production

// Mock User Data (for Development)
static const String mockUserId = 'mock-user-001';
static const String mockUserEmail = 'nurse@test.com';
static const String mockUserFirstName = 'สมหญิง';
static const String mockUserLastName = 'ใจดี';
```

### API Configuration

Update the base URL in `lib/core/constants/app_constants.dart`:

```dart
static const String baseUrl = 'https://api.medshift.co.th';
```

### Business Rules

Customize business rules in `app_constants.dart`:

```dart
static const double cancellationFee = 50.0; // THB
static const int maxTravelTimeMinutes = 120; // 2 hours
static const double hourlyRateMin = 200.0; // THB
static const double hourlyRateMax = 1000.0; // THB
static const int maxWaitlistSize = 10;
```

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design patterns
- **[DEVELOPMENT_CONFIG.md](DEVELOPMENT_CONFIG.md)** - Development mode & bypass login guide
- **[ENHANCED_FEATURES.md](ENHANCED_FEATURES.md)** - Feature documentation
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Project overview and summary
- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and changes

## 🧪 Testing

Run tests:

```bash
flutter test
```

Run with coverage:

```bash
flutter test --coverage
```

Run app on different platforms:

```bash
flutter run -d chrome          # Web browser
flutter run -d windows         # Windows desktop
flutter run -d edge            # Edge browser
flutter devices                # List available devices
```

## 📱 Screenshots

(Add your app screenshots here)

## 🛣️ Roadmap

### ✅ Completed
- [x] Development mode with bypass login
- [x] Manual JSON serialization (no build_runner)
- [x] Core models and providers
- [x] UI screens (Login, Home, Job Feed, Wallet, Profile)
- [x] Conflict detection system
- [x] Smart routing helper

### 🚧 In Progress
- [ ] Authentication & Authorization with JWT
- [ ] API integration with backend

### 📋 Planned
- [ ] Push Notifications
- [ ] Real-time Chat
- [ ] Advanced Filtering & Search
- [ ] Job History & Analytics
- [ ] Multi-language Support (EN/TH)
- [ ] Dark Mode
- [ ] Offline Support
- [ ] Rating & Review System
- [ ] Referral Program

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👥 Authors

- Senior Flutter Developer Team

## 🙏 Acknowledgments

- Flutter Team for the amazing framework
- Material Design Team for the design system
- Thai healthcare workers for their dedication

---

## ⚠️ Important Notes

- **Development Mode**: Currently enabled with bypass login for testing
- **No API Required**: App runs with mock data in development mode
- **Manual JSON Serialization**: No build_runner or code generation needed
- **Production Ready**: Disable development mode flags before deployment

## 🐛 Troubleshooting

### Build_runner errors (if you see them)
```bash
# Remove generated files
Remove-Item -Force lib\models\*.g.dart

# This project doesn't use build_runner anymore
# All JSON serialization is manual
```

### Flutter version issues
```bash
flutter doctor          # Check Flutter installation
flutter upgrade         # Upgrade to latest Flutter
flutter clean           # Clean build cache
flutter pub get         # Re-fetch dependencies
```

### Cannot run on Chrome
```bash
flutter config --enable-web    # Enable web support
flutter run -d chrome          # Run on Chrome
```

## 💡 Development Tips

1. **Quick Development**: Use bypass login mode for fast iteration
2. **Testing**: Login with any email/password when bypass mode is on
3. **Debugging**: Check console for `🚀 BYPASS LOGIN MODE` messages
4. **Production**: Remember to disable development flags before release
5. **Hot Reload**: Press `r` in terminal to hot reload, `R` to hot restart

## 📞 Support

For support, email support@medshift.co.th or join our Slack channel.

---

**Built with ❤️ for Thailand's Healthcare Sector**
