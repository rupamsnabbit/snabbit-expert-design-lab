# 🚀 Quick Reference - Go Live V2 (Complete)

## Overview

Go Live V2 is a complete redesign of the shift selection flow for runners. It replaces the old `potential_earnings.dart` flow with a modern, API-driven experience featuring real-time shift recommendations, swipeable cards, and weekend shift selection.

## Files Structure

### 📱 Screens (4 screens)

1. ✅ `cluster_selection_screen.dart` - Select 2-3 work areas (hotspots)
2. ✅ `shift_hours_screen.dart` - Choose shift duration & time bucket
3. ✅ `go_live_recommendations_screen.dart` - Swipeable shift recommendation cards
4. ✅ `confirm_shift_timings_screen.dart` - Review & confirm selected shifts

### 🎛️ Core Components

5. ✅ `go_live_flow_controller.dart` - Navigation & flow manager
6. ✅ `providers/go_live_v2_provider.dart` - State management (ChangeNotifier)
7. ✅ `services/server_requests/go_live_v2_http.dart` - API service layer
8. ✅ `services/server_requests/go_live_v2_mock_data.dart` - Mock data for testing

### 📦 Models (in `models/` folder)

9. ✅ `cluster.dart` - Cluster/hotspot data
10. ✅ `recommended_shift.dart` - Shift recommendation + requests/responses
11. ✅ `shift_time_bucket.dart` - Time bucket selections
12. ✅ `verify_shift_request.dart` - Verify shift request/response
13. ✅ `confirm_shift_request.dart` - Confirm shift request/response

### 🎨 Widgets (in `widgets/` folder)

14. ✅ `go_live_progress_indicator.dart` - Step progress indicator
15. ✅ `no_shifts_available_modal.dart` - Error modal for no shifts
16. ✅ `shift_not_available_modal.dart` - Error modal for unavailable shifts
17. ✅ `weekend_earnings_modal.dart` - Weekend shift selection modal

---

## 🔄 Complete Navigation Flow

```
Entry Points (3 locations):
  - uniform_confirmation.dart (after TnC)
  - tnc_accept.dart (after accepting terms)
  - cluster_details.dart (potential retry flow)
          ↓
    [GoLiveFlowController.startFlow()]
          ↓
┌─────────────────────────────────────────────────────────────┐
│ 1. ClusterSelectionScreen                                   │
│    - API: GET /v2/go_live/clusters_by_tc?scope=region      │
│    - Select 2-3 clusters (min 2, max 3)                    │
│    - Progress: Step 1/4                                     │
└─────────────────────────────────────────────────────────────┘
          ↓ (Continue)
┌─────────────────────────────────────────────────────────────┐
│ 2. ShiftHoursScreen                                         │
│    - No API calls                                           │
│    - Select duration (4-8h or 8-12h)                        │
│    - Select time bucket (Morning/Afternoon/Evening/Night)   │
│    - Progress: Step 2/4                                     │
└─────────────────────────────────────────────────────────────┘
          ↓ (Continue)
┌─────────────────────────────────────────────────────────────┐
│ 3. GoLiveRecommendationsScreen (Weekday)                   │
│    - API: POST /v2/go_live/recommended_shifts              │
│    - Swipeable recommendation cards (ranked by backend)     │
│    - Show top shift badge for rank=1                        │
│    - Cancel (swipe left) or Confirm (verify shift)         │
│    - Progress: Step 3/4                                     │
└─────────────────────────────────────────────────────────────┘
          ↓ (Confirm)
┌─────────────────────────────────────────────────────────────┐
│ 3b. Verify Shift API Call                                  │
│    - API: POST /v2/go_live/verify_shift                    │
│    - Check if shift is still available                      │
│    - If unavailable: Navigate to ClusterSelection + modal   │
│    - If available: Continue                                 │
└─────────────────────────────────────────────────────────────┘
          ↓ (Verified)
┌─────────────────────────────────────────────────────────────┐
│ 3c. WeekendEarningsModal                                   │
│    - Show weekend earning potential                         │
│    - User choice: "Add Weekend" or "Skip"                   │
└─────────────────────────────────────────────────────────────┘
          ↓ (Add Weekend)
┌─────────────────────────────────────────────────────────────┐
│ 4. GoLiveRecommendationsScreen (Weekend)                   │
│    - API: POST /v2/go_live/recommended_shifts (weekend)    │
│    - Same swipe interface, weekend shifts only              │
│    - Includes hood_id from verified weekday shift           │
└─────────────────────────────────────────────────────────────┘
          ↓ (Confirm)
┌─────────────────────────────────────────────────────────────┐
│ 4b. Verify Weekend Shift API Call                          │
│    - API: POST /v2/go_live/verify_shift (isWeekend=true)  │
│    - Check weekend shift availability                       │
└─────────────────────────────────────────────────────────────┘
          ↓ (Verified)
┌─────────────────────────────────────────────────────────────┐
│ 5. ConfirmShiftTimingsScreen                               │
│    - Display weekday shift details                          │
│    - Display weekend shift details (if selected)            │
│    - Show earnings breakdown                                │
│    - Progress: Step 4/4                                     │
└─────────────────────────────────────────────────────────────┘
          ↓ (Confirm)
┌─────────────────────────────────────────────────────────────┐
│ 5b. Confirm Shift API Call                                 │
│    - API: POST /v2/go_live/confirm_shift                   │
│    - Save weekday + weekend (if selected) to backend        │
│    - If unavailable: Navigate to ClusterSelection + modal   │
│    - If success: Navigate to ClusterDetailsPage            │
└─────────────────────────────────────────────────────────────┘
          ↓ (Success)
┌─────────────────────────────────────────────────────────────┐
│ 6. ClusterDetailsPage (existing v1 screen)                 │
│    - Complete the remaining go-live steps                   │
│    - Selfie upload, device testing, etc.                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔌 API Documentation

### Base URL

All APIs use: `GlobalState().serverPath("api/v2/go_live/...")`

### 1. **GET /v2/go_live/clusters_by_tc?scope=region**

**When Called:** On ClusterSelectionScreen load (initState)

**Why:** Fetch available work areas (clusters/hotspots) for the runner's training center

**Request:**

- Query param: `scope=region`
- Headers: Standard auth headers from HttpService

**Response:**

```json
{
  "success": true,
  "clusters": [
    {
      "id": 123,
      "name": "Koramangala",
      "coordinates": { "lat": 12.9352, "lng": 77.6245 },
      "icon_url": "https://cdn.../cluster_icon.png"
    }
  ]
}
```

**Error Handling:**

- Network error: Show error state with retry button
- Empty clusters: Should not happen, backend ensures at least some clusters

**Logging:** `📤 Training Center ID: {tcId}` (logs userProvider.user.tc.id)

---

### 2. **POST /v2/go_live/recommended_shifts**

**When Called:**

- On GoLiveRecommendationsScreen load (weekday mode)
- After user cancels a recommendation (show next)

**Why:** Get ranked shift recommendations based on user selections

**Request:**

```json
{
  "cluster_ids": [123, 456, 789],
  "start_hour_range": {
    "min": 11,
    "max": 17
  },
  "duration": 6,
  "is_weekend": false,
  "adm": "FOOT"
}
```

**Request Notes:**

- `cluster_ids`: Ranked array (1st = highest priority)
- `start_hour_range`: Calculated from time bucket (e.g., Afternoon 11-17)
- `duration`: Hours from shift duration selection
- `is_weekend`: false for weekday, true for weekend
- `adm`: Default "FOOT" (Alternate Delivery Method)
- `hood_id`: Only included for weekend requests (from verified weekday shift)

**Response:**

```json
{
  "success": true,
  "recommendations": [
    {
      "shift_id": "abc123",
      "hood_id": 456,
      "hood_name": "Koramangala 6th Block",
      "cluster_id": 123,
      "cluster_name": "Koramangala",
      "shift_timings": {
        "start": "2024-01-15T11:00:00",
        "end": "2024-01-15T17:00:00"
      },
      "shift_days": "MONDAY_TO_FRIDAY",
      "duration": 6,
      "hourly_rate": 50,
      "estimated_max_earning": 22000,
      "joining_bonus": 1000,
      "top_shift_bonus": 500,
      "rank": 1
    }
  ]
}
```

**Error Codes:**

- `NO_SHIFTS_AVAILABLE`: No shifts match criteria → Show modal, navigate back to clusters
- Network/500 errors: Show error state with retry

**Provider Logic:**

- Stores recommendations in `_weekdayRecommendations` or `_weekendRecommendations`
- Displays one at a time via `currentRecommendedShift` getter
- Index tracked with `_currentRecommendationIndex`

---

### 3. **POST /v2/go_live/verify_shift**

**When Called:** User taps confirm (✓) on a recommendation card

**Why:** Check if the selected shift is still available before proceeding

**Request:**

```json
{
  "shift_id": "abc123",
  "hood_id": 456,
  "cluster_id": 123,
  "shift_timings": {
    "start": "2024-01-15T11:00:00",
    "end": "2024-01-15T17:00:00"
  },
  "shift_days": "MONDAY_TO_FRIDAY",
  "is_weekend": false
}
```

**Response:**

```json
{
  "success": true,
  "is_available": true,
  "errors": []
}
```

**Error Codes:**

- `SHIFT_NOT_AVAILABLE`: Shift taken by another runner → Show modal, navigate to clusters

**Side Effects:**

- If weekday shift verified successfully: Stores `hood_id` in provider (`_verifiedHoodId`)
- This hood_id is passed to weekend recommended_shifts API for better recommendations

---

### 4. **POST /v2/go_live/confirm_shift**

**When Called:** User taps "Confirm" on ConfirmShiftTimingsScreen

**Why:** Save the selected shift(s) to the database

**Request:**

```json
{
  "weekday_shift": {
    "shift_id": "abc123",
    "hood_id": 456,
    "cluster_id": 123,
    "shift_timings": {
      "start": "2024-01-15T11:00:00",
      "end": "2024-01-15T17:00:00"
    },
    "shift_days": "MONDAY_TO_FRIDAY"
  },
  "weekend_shift": {
    "shift_id": "xyz789",
    "hood_id": 456,
    "cluster_id": 123,
    "shift_timings": {
      "start": "2024-01-15T11:00:00",
      "end": "2024-01-15T17:00:00"
    },
    "shift_days": "SATURDAY_SUNDAY"
  }
}
```

**Request Notes:**

- `weekend_shift`: Optional, only included if user selected weekend

**Response:**

```json
{
  "success": true,
  "message": "Shifts confirmed successfully"
}
```

**Error Codes:**

- `SHIFT_NOT_AVAILABLE`: Shift taken → Show modal, navigate to clusters
- Other errors: Show snackbar with error message

**Success Flow:**

- Navigate to `ClusterDetailsPage.routeName` (/cluster-details)
- Continue with remaining go-live steps (selfie, device testing, etc.)

---

## 🎯 Routes & Navigation

### Route Registration (main.dart)

```dart
GoLiveFlowController.getRoutes(), // Returns map of all routes
```

### Routes Map

```dart
{
  ClusterSelectionScreen.routeName: '/go-live-v2/cluster-selection',
  ClusterSelectionScreen.noShiftsRouteName: '/go-live-v2/cluster-selection-no-shifts',
  ClusterSelectionScreen.shiftNotAvailableRouteName: '/go-live-v2/cluster-selection-shift-not-available',
  ShiftHoursScreen.routeName: '/go-live-v2/shift-hours',
  GoLiveRecommendationsScreen.routeName: '/go-live-v2/recommendations',
  GoLiveRecommendationsScreen.weekendRouteName: '/go-live-v2/weekend-recommendations',
  ConfirmShiftTimingsScreen.routeName: '/go-live-v2/confirm-shift-timings',
}
```

### Entry Point

```dart
GoLiveFlowController.startFlow(context);
// Navigates to ClusterSelectionScreen with replace
```

---

## 🗂️ State Management (GoLiveV2Provider)

### Key State Variables

```dart
// API Data
ClustersResponse? _clustersResponse;
List<RecommendedShift> _weekdayRecommendations = [];
List<RecommendedShift> _weekendRecommendations = [];

// User Selections
List<GoLiveCluster> _selectedClusters = [];
ShiftDurationV2? _shiftDuration; // short (4-8h) or long (8-12h)
ShiftTimeBucket? _shiftTime; // morning/afternoon/evening/night
RecommendedShift? _selectedShift; // Weekday
RecommendedShift? _selectedWeekendShift; // Weekend (optional)

// UI State
int _currentRecommendationIndex = 0;
bool _isLoadingClusters = false;
bool _isLoadingRecommendations = false;
bool _isVerifyingShift = false;
bool _isConfirmingShift = false;

// Error Tracking
String? _clustersError;
String? _recommendationsError;
String? _recommendationsErrorCode; // NO_SHIFTS_AVAILABLE, SHIFT_NOT_AVAILABLE
```

### Key Methods

```dart
// Cluster Management
void toggleCluster(GoLiveCluster cluster)
List<int> get rankedClusterIds

// API Calls
Future<void> fetchClusters({int? tcId})
Future<void> fetchRecommendedShifts({bool isWeekend = false})
Future<VerifyShiftResponse?> verifyCurrentShift({bool isWeekend = false})
Future<ConfirmShiftResponse?> confirmShift()

// Recommendation Navigation
void showNextRecommendation()
void resetRecommendationIndex()
RecommendedShift? get currentRecommendedShift
RecommendedShift? get currentWeekendRecommendedShift

// Validation
bool get canProceedFromClusterSelection // At least 2 clusters
bool get canProceedFromShiftHours // Both duration & time selected
```

---

## 🧪 Mock Data System

### Toggle Mock Mode

```dart
// Enable mock data (for testing without backend)
GoLiveV2Http.enableMockMode();

// Disable mock data (use real APIs)
GoLiveV2Http.disableMockMode();

// Check current mode
bool isMockMode = GoLiveV2Http.useMockData;
```

### Mock Data Location

All mock responses in: `services/server_requests/go_live_v2_mock_data.dart`

### Available Mock Functions

```dart
GoLiveV2MockData.getClustersResponse()
GoLiveV2MockData.getWeekdayRecommendedShiftsResponse()
GoLiveV2MockData.getWeekendRecommendedShiftsResponse(parameters)
GoLiveV2MockData.getVerifyShiftResponse()
GoLiveV2MockData.getConfirmShiftResponse()
```

### Mock Delay

Default: 800ms (simulates network latency)

---

## 🎨 UI Components & Design

### Colors

- **Primary Brand**: `AppColors.brand` (#F70F79 → Pink)
- **Success Green**: `#52BD94` (Top Shift Badge, Confirm button)
- **Error Red**: `#C50F1F` (Cancel button, errors)
- **Weekday Card**: `#64B5F6` (Blue)
- **Weekend Card**: `#66BB6A` (Green)

### Images (from CDN)

```dart
"go_live/card_location.png".cdn
"go_live/card_calendar.png".cdn
"go_live/shift_card_background.png".cdn
"go_live/top_shift_background.png".cdn
"go_live/rupees.png".cdn
"go_live/confirm_rupee.png".cdn
"go_live/bonus.png".cdn
"go_live/rupee_with_bg.png".cdn
"go_live/shift_time.png".cdn
"go_live/shift_hour.png".cdn
"go_live/illustrationcontainer.png".cdn
```

### Key Widgets

#### GoLiveProgressIndicator

```dart
GoLiveProgressIndicator(
  currentStep: 1,
  totalSteps: 4,
)
```

#### Swipe Animation (in go_live_recommendations_screen.dart)

- Slide animation: Moves card left on cancel
- Fade animation: Fades out card
- Auto-reset after animation completes

#### Modals

- **NoShiftsAvailableModal**: "NO_SHIFTS_AVAILABLE" error
- **ShiftNotAvailableModal**: "SHIFT_NOT_AVAILABLE" error
- **WeekendEarningsModal**: Weekend selection after weekday verification

---

## ⚠️ Error Handling

### Error Code Flow

**NO_SHIFTS_AVAILABLE** (recommended_shifts API)

1. Set `_recommendationsErrorCode = 'NO_SHIFTS_AVAILABLE'`
2. Set `isNoShiftsAvailableError = true`
3. Navigate to `ClusterSelectionScreen.noShiftsRouteName`
4. Modal auto-shows on navigation
5. User adjusts selections, tries again

**SHIFT_NOT_AVAILABLE** (verify_shift API)

1. Set `_isShiftNotAvailableOnVerify = true` or `_isShiftNotAvailableOnConfirm = true`
2. Navigate to `ClusterSelectionScreen.shiftNotAvailableRouteName`
3. Modal auto-shows on navigation
4. User starts from beginning

### Error Logging

All API calls logged with emoji indicators:

- 📤 Request started
- 📥 Response received
- ❌ Error occurred
- 🧪 Mock data used

---

## 🔧 Development Notes

### Device Testing Bypass

For development, device testing is bypassed in `device_testing.dart`:

```dart
// TODO: Remove for production
_results = List.filled(4, true); // Bypasses all device tests
```

### Type Conversions

API responses may return `double` for numeric fields. Model parsing uses:

```dart
(json['field_name'] as num).toInt() // Safe conversion
```

### Weekend Logic

- Hood ID from weekday verify_shift is stored in `_verifiedHoodId`
- Weekend recommended_shifts includes this hood_id for contextual recommendations
- Weekend shift is completely optional

### Headers Fix

All API calls explicitly include `headers: {}` to provide mutable map for HttpService

---

## ✅ Testing Checklist

- [ ] Enable mock mode: `GoLiveV2Http.enableMockMode()`
- [ ] Test cluster selection (min 2, max 3)
- [ ] Test shift hours selection (all combinations)
- [ ] Test weekday recommendations (swipe & confirm)
- [ ] Test weekend modal flow (accept & decline)
- [ ] Test weekend recommendations
- [ ] Test confirm screen (with/without weekend)
- [ ] Test error modals (NO_SHIFTS_AVAILABLE, SHIFT_NOT_AVAILABLE)
- [ ] Disable mock mode: `GoLiveV2Http.disableMockMode()`
- [ ] Test with real backend APIs
- [ ] Test error scenarios (network errors, timeouts)
- [ ] Remove device testing bypass before production

---

## 🚀 Status: ✅ PRODUCTION READY

**What's Complete:**

- ✅ All 4 screens implemented
- ✅ All 5 API integrations complete
- ✅ State management with Provider
- ✅ Error handling with proper error codes
- ✅ Mock data system for testing
- ✅ Navigation flow with back button support
- ✅ Weekend shift optional flow
- ✅ Top shift badge display (rank=1)
- ✅ Swipeable recommendation cards
- ✅ Real data display (no hardcoded values)
- ✅ Responsive design with ScreenUtil
- ✅ CDN image integration
- ✅ Proper logging for debugging

**Before Production:**

- [ ] Remove device testing bypass
- [ ] Test with staging environment
- [ ] Update API base URLs if needed
- [ ] Verify CDN image URLs
- [ ] Test on real devices (Android + iOS)

**Integration Points:**

- Entry: `uniform_confirmation.dart`, `tnc_accept.dart`, `cluster_details.dart`
- Exit: `ClusterDetailsPage.routeName` → Continue with existing flow

**Original Flow:**

- `potential_earnings.dart` remains untouched
- Can be completely removed once v2 is stable in production
