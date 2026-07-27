# MedShift Thailand - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Install Dependencies

Open your terminal in the project directory and run:

```bash
flutter pub get
```

### Step 2: Generate JSON Serialization Code

The models use JSON serialization. Generate the required files:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will create `.g.dart` files for:

- `job_model.g.dart`
- `staff_profile_model.g.dart`
- `transaction_model.g.dart`

### Step 3: Run the App

Connect your device/emulator and run:

```bash
flutter run
```

## 📱 First Look

### What You'll See

1. **Job Feed Screen** - Browse available medical staffing jobs
2. **Wallet Screen** - View balance and transaction history
3. **Profile Screen** - Manage your professional profile

### Navigation

The app uses bottom navigation with 3 tabs:

- 🏥 **Jobs** - Available positions
- 💰 **Wallet** - Financial management
- 👤 **Profile** - Your information

## 🧪 Test the Features

### 1. Browse Jobs

- Pull to refresh the job list
- Tap on a job to see details
- View job information (time, location, pay)

### 2. Apply for a Job

- Tap "Apply for this Job" button
- The system checks for scheduling conflicts
- Confirmation dialog appears

### 3. View Wallet

- Check your current balance
- Review transaction history
- See earnings and penalties

### 4. Profile Management

- View your professional information
- See skills and certifications
- Toggle availability status

## ⚙️ Configuration

### Update API Endpoint

Before connecting to your backend, update the API URL:

File: `lib/core/constants/app_constants.dart`

```dart
static const String baseUrl = 'https://YOUR-API-URL.com';
```

### Customize Theme Colors

File: `lib/core/theme/app_theme.dart`

```dart
static const Color primaryColor = Color(0xFF00796B); // Change this
static const Color secondaryColor = Color(0xFF004D40); // And this
```

### Adjust Business Rules

File: `lib/core/constants/app_constants.dart`

```dart
static const double cancellationFee = 50.0; // THB
static const int maxTravelTimeMinutes = 120; // minutes
static const int maxWaitlistSize = 10; // staff members
```

## 🔧 Common Issues

### Issue: "Missing generated files"

**Solution**: Run the build runner:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Plugin not found"

**Solution**: Clean and reinstall:

```bash
flutter clean
flutter pub get
```

### Issue: "Gradle build failed" (Android)

**Solution**: Update Android SDK and Gradle:

```bash
flutter doctor
```

### Issue: "Pod install failed" (iOS)

**Solution**: Update CocoaPods:

```bash
cd ios
pod install
cd ..
```

## 📚 Key Concepts

### 1. Waitlist Model

When a job is filled:

- Additional applicants are placed on a waitlist
- If the hired staff cancels, the first person on the waitlist is notified
- Maximum 10 people on waitlist per job

### 2. Conflict Detection

The app prevents double-booking:

- Checks all your hired jobs
- Compares time ranges
- Optionally includes buffer time for travel

### 3. Negative Balance

Staff can have negative balance:

- Canceling a job costs 50 THB
- Balance can go below zero
- Must complete jobs to clear debt
- Wallet screen shows warning if balance is negative

### 4. Smart Routing

The app calculates travel logistics:

- Distance using Haversine formula
- Estimated travel time (assumes 30 km/h in Bangkok)
- Travel cost estimation
- Filters jobs by acceptable travel time

## 🎯 Next Steps

### For Development

1. **Implement Authentication**
   - Create auth service
   - Add login/signup screens
   - Manage tokens in providers

2. **Connect to Backend API**
   - Replace mock data
   - Implement all API endpoints
   - Add error handling

3. **Add More Features**
   - Push notifications
   - Real-time updates
   - Chat functionality
   - Advanced filters

### For Production

1. **Security**
   - Add authentication
   - Secure API calls
   - Implement token refresh
   - Add biometric login

2. **Testing**
   - Write unit tests
   - Add integration tests
   - Perform QA testing

3. **Deployment**
   - Configure release builds
   - Set up CI/CD
   - Submit to app stores

## 📖 Documentation

- [Full README](README.md) - Complete project documentation
- [Architecture Guide](ARCHITECTURE.md) - Technical architecture details

## 💡 Tips

1. **Hot Reload**: Press `r` in terminal while app is running for quick updates
2. **Hot Restart**: Press `R` for full restart
3. **DevTools**: Press `v` to open Flutter DevTools
4. **Logs**: Use `flutter logs` to view detailed logs

## 🆘 Need Help?

- Check the README.md for detailed documentation
- Review the code comments
- Run `flutter doctor` to check your setup
- Join Flutter community on Discord/Slack

---

Happy Coding! 🎉
