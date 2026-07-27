# MedShift Thailand - Enhanced Features Guide

## 🎨 New UI Components & Features

This document describes the professional medical UI enhancements added to the MedShift Thailand app.

---

## 1. 📋 Enhanced Job Card & Feed

### JobCard Widget Enhancements

The job card now features a **professional medical design** with comprehensive information:

#### Key Features:

**🏥 Clinic/Hospital Display**

- Medical icon badge (teal background)
- Clinic name displayed prominently
- Job title (e.g., "ICU Nurse", "Emergency RN")

**💰 Price Badge**

- Gradient teal background with shadow
- Large, prominent ฿ price display
- Positioned in top-right corner

**🗺️ Smart Route Row**

- Blue info-colored container
- Travel distance calculation (in km)
- Estimated travel time (based on Bangkok traffic at 30 km/h)
- Icons: car + clock + navigation
- Example: "5.2 km · ~10 mins"

**✅ Reliability Badge**

- Green badge if user meets requirements
- Orange/yellow warning if user doesn't meet minimum score
- Displays: "Eligible to Apply" or "Min. 75% Reliability Required"
- Icon changes based on eligibility

**📅 Date & Time Display**

- Clean, icon-based layout
- Date format: "MMM dd, yyyy"
- Time format: "HH:mm - HH:mm"

**🎯 Required Skills Preview**

- Shows first 3 required skills
- Teal-colored chips
- Compact, professional design

### Usage Example:

```dart
JobCard(
  job: jobModel,
  currentLat: 13.7563,  // Bangkok
  currentLng: 100.5018,
  userReliabilityScore: 87.5,
  onTap: () {
    // Navigate to detail screen
  },
)
```

### Visual Hierarchy:

```
┌─────────────────────────────────────┐
│ 🏥 Icon  Clinic Name        ฿1,200  │
│         Job Title                    │
├─────────────────────────────────────┤
│ 🚗 ⏰ 5.2 km · ~10 mins     🧭      │
├─────────────────────────────────────┤
│ ✓ Eligible to Apply                 │
├─────────────────────────────────────┤
│ 📅 May 15, 2026  ⏰ 08:00 - 16:00  │
├─────────────────────────────────────┤
│ [IV Therapy] [ICU] [Emergency]      │
└─────────────────────────────────────┘
```

---

## 2. 👤 Enhanced Profile Screen with Reliability Gauge

### The Reliability Score Gauge

A **semi-circular gauge** displaying the user's reliability score (0-100%).

#### Visual Design:

- **Size**: Customizable (default 200px width)
- **Shape**: Semi-circle (180° arc)
- **Colors**: Dynamic based on score
  - 90-100%: Green (#4CAF50)
  - 75-89%: Light Green (#66BB6A)
  - 60-74%: Orange (#FFA726)
  - 40-59%: Dark Orange
  - 0-39%: Red (#E53935)

#### Components:

1. **Background Arc**: Gray base layer
2. **Progress Arc**: Colored gradient fill
3. **Score Display**: Large percentage text
4. **Status Badge**: "Active" with trending up icon
5. **Level Text**: "Excellent", "Very Good", "Good", etc.
6. **Description**: "Based on your performance and attendance"

#### Implementation:

The gauge uses **Custom Painters** for smooth rendering:

```dart
ReliabilityGauge(
  score: 87.5,  // 0-100
  size: 200,    // Width in pixels
)
```

**Custom Painters:**

- `GaugeBackgroundPainter`: Draws the gray background arc
- `GaugeProgressPainter`: Draws the colored progress arc with gradient

### Statistics Grid

Three prominent stat cards showing:

**💰 Total Earnings**

- Icon: payments (green)
- Value: ฿145,600
- Label: "Total Earnings"

**💼 Completed Shifts**

- Icon: work_history (teal)
- Value: 127
- Label: "Completed"

**👥 Referrals**

- Icon: people (accent color)
- Value: 12
- Label: "Referrals"

### Verified Skills Section

**🎯 Professional Skills Display:**

- Title: "Verified Skills" with verified icon
- Chips with medical icons:
  - IV Therapy (💧 drink icon)
  - Emergency Care (🚨 emergency icon)
  - ICU (💗 monitor_heart icon)
  - Surgical Assist (🔪 surgical icon)
  - Pediatric Care (👶 child_care icon)
- Color-coded with teal theme
- Border for emphasis

### Layout Structure:

```
┌──────────────────────────────────────┐
│         Profile Header               │
│      (Gradient Background)           │
│   Avatar + Name + Specialty          │
│         ⭐ 4.8 Rating                │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│      Reliability Score Gauge         │
│          ╭─────────╮                 │
│         │  87.5%  │                 │
│          ╰─────────╯                 │
│         Very Good                    │
└──────────────────────────────────────┘

┌─────────┐  ┌─────────┐
│ ฿145,600│  │   127   │
│ Earnings│  │Completed│
└─────────┘  └─────────┘

┌──────────────────────────────────────┐
│         ฿12 Referrals                │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  ✅ Verified Skills                  │
│  [💧 IV Therapy] [🚨 Emergency]     │
│  [💗 ICU] [🔪 Surgical]             │
└──────────────────────────────────────┘
```

---

## 3. 💳 Enhanced Wallet Screen

### Balance Card Enhancements

**Visual States:**

#### Positive Balance:

- Gradient: Teal → Dark Teal
- Large ฿ amount in **white text**
- Wallet icon
- "Account in good standing" message

#### Negative Balance (Critical Feature):

- Gradient: Red → Dark Red
- Large ฿ amount in **RED text** ⚠️
- Warning icon
- "Account Limited" alert box

### Negative Balance Alert Box

When balance is negative, shows:

**🔒 Account Limited Card:**

- White semi-transparent background
- Lock icon
- Title: "Account Limited"
- Message: "Your account has a negative balance. Complete jobs or pay to unlock full access."
- **"Pay to Unlock Account" button** (white with red text)

### Payment Dialog

When user clicks "Pay to Unlock Account":

```
┌─────────────────────────────────────┐
│  Pay Outstanding Balance            │
├─────────────────────────────────────┤
│  Amount to pay:                     │
│  ฿50.00 (in RED)                    │
│                                     │
│  This will clear your negative      │
│  balance and unlock your account.   │
├─────────────────────────────────────┤
│  [Cancel]  [Proceed to Payment]     │
└─────────────────────────────────────┘
```

### Transaction History Enhancements

**Transaction Card Features:**

#### Visual Design:

- Circular icon badge (colored by transaction type)
- Transaction description
- Date & time stamp
- Amount with color coding:
  - **Green** for income/payments (+)
  - **Red** for penalties (-)
- Current balance after transaction

#### Penalty-Specific Features:

**📄 PDF Receipt Download:**

- Additional "receipt available" label
- Download icon button (blue)
- Clicking shows success snackbar
- Example: "Receipt for Job cancellation penalty"

**Transaction Types & Icons:**

- 💰 Payment → Green (attach_money)
- ⚠️ Penalty → Red (warning_amber_rounded)
- 🔄 Refund → Blue (replay)
- ⭐ Bonus → Orange (star)

### Transaction Card Layout:

```
┌──────────────────────────────────────────┐
│ (⚠️) Job Cancellation Penalty            │
│      May 14, 2026 10:30               📥 │
│      Receipt available                    │
│                          -฿50.00 (RED)    │
│                          Bal: ฿950        │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ (💰) ICU Shift Payment                    │
│      May 13, 2026 18:00                   │
│                          +฿1,200 (GREEN)  │
│                          Bal: ฿1,000      │
└──────────────────────────────────────────┘
```

---

## 🎨 Design System & Theme

### Color Palette

**Primary Colors:**

```dart
Primary: #00796B (Teal)
Secondary: #004D40 (Dark Teal)
Accent: #26A69A
```

**Status Colors:**

```dart
Success: #4CAF50 (Green)
Warning: #FFA726 (Orange)
Error: #E53935 (Red)
Info: #42A5F5 (Blue)
```

**Medical-Specific:**

- Reliability badges: Green/Orange
- Travel info: Blue
- Negative balance: Red with warning

### Typography

**Fonts:**

- **Headings**: Prompt (Thai support)
- **Body**: Inter (Modern, professional)

**Font Sizes:**

- Display: 48-57px (balance amounts)
- Headline: 28-36px (section titles)
- Title: 16-22px (card titles)
- Body: 14-16px (content)
- Small: 12px (labels, hints)

### Icons

**Medical Icons Used:**

- 🏥 `local_hospital` - Hospitals/clinics
- 💊 `medication` - Medication administration
- 🩺 `health_and_safety` - Patient assessment
- 🚑 `emergency` - Emergency care
- 💗 `monitor_heart` - ICU/monitoring
- 🔪 `surgical` - Surgical procedures
- 👶 `child_care` - Pediatric care
- 💉 `healing` - Wound care

### Spacing & Layout

**Padding:**

- Cards: 16px
- Sections: 24px
- Between elements: 8-12px

**Border Radius:**

- Cards: 12-16px
- Buttons: 8px
- Chips: 4-20px
- Badges: 20px (pill shape)

**Shadows:**

```dart
BoxShadow(
  color: color.withOpacity(0.3),
  blurRadius: 8-12,
  offset: Offset(0, 2-4),
)
```

---

## 📱 Responsive Behavior

### Mobile Optimizations:

1. **Job Cards**: Stack elements vertically on small screens
2. **Stats Grid**: 2-column layout for earnings/completed, full-width for referrals
3. **Gauge**: Scales proportionally
4. **Transaction Cards**: Icon button size adjusts for tap targets

---

## 🔧 Implementation Details

### Required Model Updates

**StaffProfileModel:**

```dart
double reliabilityScore (0-100)
double totalEarnings
int referralCount
List<String> verifiedSkills
```

**JobModel:**

```dart
double minReliabilityScore (default 60.0)
String? clinicName
String displayName (getter: clinicName ?? hospitalName)
```

### Key Methods

**Smart Route Helper:**

```dart
SmartRouteHelper.getTravelInfo(
  startLat, startLng,
  endLat, endLng,
) → "5.2 km · ~10 mins"
```

**Reliability Check:**

```dart
userScore >= job.minReliabilityScore
```

**Balance Check:**

```dart
provider.hasNegativeBalance
provider.balance (can be negative!)
```

---

## 🎯 User Experience Flow

### Job Application Flow:

1. User browses job feed
2. Sees travel time and distance
3. Checks reliability requirement
4. Green badge → Can apply ✅
5. Orange badge → Need to improve score ⚠️
6. Tap card → View full details

### Profile View Flow:

1. Open profile screen
2. See reliability gauge with score
3. Understand performance level
4. View verified skills with icons
5. Check statistics (earnings, shifts, referrals)
6. Review all skills and certifications

### Wallet Flow:

1. Open wallet screen
2. **Positive Balance:**
   - See balance in white
   - View transaction history
   - Download receipts
3. **Negative Balance:**
   - See balance in RED
   - Read warning message
   - Tap "Pay to Unlock Account"
   - Process payment

---

## 🚀 Testing Checklist

### Job Card:

- [ ] Clinic name displays correctly
- [ ] Travel time calculates accurately
- [ ] Reliability badge shows correct status
- [ ] Price badge is prominent
- [ ] Icons render properly
- [ ] Card taps navigate to details

### Profile:

- [ ] Gauge displays correct percentage
- [ ] Gauge color matches score
- [ ] Stats cards show accurate numbers
- [ ] Verified skills display with icons
- [ ] Layout is responsive

### Wallet:

- [ ] Positive balance shows in white
- [ ] Negative balance shows in RED
- [ ] "Pay to Unlock" button appears when negative
- [ ] Payment dialog works
- [ ] Transaction colors are correct (green/red)
- [ ] PDF download button appears for penalties
- [ ] Download snackbar shows

---

## 💡 Pro Tips

1. **Custom Location**: Update mock location in `_getCurrentLocation()` with actual GPS
2. **Real Data**: Replace mock profile data with API calls
3. **PDF Generation**: Implement actual PDF creation for receipts
4. **Payment Processing**: Integrate payment gateway (Stripe, PayPal, etc.)
5. **Animations**: Add subtle animations to gauge for polish
6. **Loading States**: Show skeleton loaders while calculating travel time

---

## 🎨 Design Credits

- **Theme**: Material Design 3
- **Colors**: Medical/Healthcare inspired (Teal green)
- **Icons**: Material Icons
- **Fonts**: Google Fonts (Prompt + Inter)
- **Inspiration**: Modern fintech + healthcare apps

---

## 📞 Support

For questions about these features:

- Review the code comments
- Check the main README.md
- See ARCHITECTURE.md for technical details

---

**Version**: 2.0.0 (Enhanced UI)  
**Last Updated**: May 14, 2026  
**Author**: Senior Flutter Development Team
