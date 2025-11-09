# HealthKit Integration Setup Guide

## Prerequisites

1. Xcode 12.0 or later
2. iOS 14.0 or later
3. Physical iOS device (HealthKit doesn't work in simulator)
4. Apple Developer account

## Step 1: Enable HealthKit Capability

1. Open your Xcode project
2. Select your target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **HealthKit**

## Step 2: Add Info.plist Entries

Add these keys to your `Info.plist` file:

```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to your health data to provide personalized sleep insights and track your progress.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>We need to update your health data to track your sleep progress and interventions.</string>
```

Or in the Info.plist editor:
- **Privacy - Health Share Usage Description**: "We need access to your health data to provide personalized sleep insights and track your progress."
- **Privacy - Health Update Usage Description**: "We need to update your health data to track your sleep progress and interventions."

## Step 3: Add Files to Project

1. Copy `HealthKitManager.swift` to your Xcode project
2. Copy `HealthKitIntegrationView.swift` to your Xcode project (if using SwiftUI)
3. Make sure both files are added to your target

## Step 4: Store Access Token

After user logs in, store the access token:

```swift
// After successful login
UserDefaults.standard.set(accessToken, forKey: "accessToken")
```

## Step 5: Use HealthKitManager

### Basic Usage

```swift
import SwiftUI

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request authorization when app launches
                    let healthKitManager = HealthKitManager()
                    healthKitManager.requestAuthorization { success, error in
                        if success {
                            print("HealthKit authorized")
                        } else {
                            print("Authorization failed: \(error?.localizedDescription ?? "Unknown")")
                        }
                    }
                }
        }
    }
}
```

### Sync Health Data

```swift
let healthKitManager = HealthKitManager()

// Sync all health data
healthKitManager.syncAllHealthData { result in
    switch result {
    case .success(let response):
        print("Sync successful: \(response)")
    case .failure(let error):
        print("Sync failed: \(error.localizedDescription)")
    }
}
```

### Manual Data Fetching

```swift
// Fetch sleep data only
healthKitManager.fetchSleepData(daysBack: 90) { result in
    switch result {
    case .success(let sleepData):
        print("Fetched \(sleepData.count) days of sleep data")
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}

// Fetch heart rate data
healthKitManager.fetchHeartRateData(daysBack: 30) { result in
    // Handle result
}

// Fetch activity data
healthKitManager.fetchActivityData(daysBack: 30) { result in
    // Handle result
}
```

## Step 6: Background Sync (Optional)

To sync health data automatically in the background:

1. Enable **Background Modes** capability
2. Check **Background fetch**
3. Implement background fetch in AppDelegate:

```swift
func application(_ application: UIApplication, 
                 performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    
    let healthKitManager = HealthKitManager()
    healthKitManager.syncAllHealthData { result in
        switch result {
        case .success:
            completionHandler(.newData)
        case .failure:
            completionHandler(.failed)
        }
    }
}
```

## Step 7: Update API Base URL

In `HealthKitManager.swift`, update the `apiBaseURL` property:

```swift
private let apiBaseURL = "https://your-production-api.com/api"
```

For development:
```swift
#if DEBUG
private let apiBaseURL = "http://localhost:3001/api"
#else
private let apiBaseURL = "https://your-production-api.com/api"
#endif
```

## Testing

1. **Test on Physical Device**: HealthKit only works on real devices, not simulators
2. **Grant Permissions**: When prompted, grant HealthKit permissions
3. **Add Test Data**: Use the Health app to add test sleep, heart rate, and activity data
4. **Verify Sync**: Check the API logs to verify data is being synced correctly

## Troubleshooting

### "HealthKit is not available"
- Make sure you're testing on a physical device
- Check that HealthKit capability is enabled

### "No access token found"
- Make sure user has logged in
- Verify token is stored in UserDefaults with key "accessToken"

### "Authorization failed"
- Check Info.plist entries are correct
- Verify HealthKit capability is enabled
- Make sure you're testing on a physical device

### "Sync failed"
- Check API server is running
- Verify network connectivity
- Check API logs for errors
- Ensure access token is valid

## Data Types Supported

- ✅ Sleep Analysis (stages: deep, light, REM, awake)
- ✅ Heart Rate (resting, average)
- ✅ Heart Rate Variability (HRV)
- ✅ Step Count
- ✅ Active Energy (calories)
- ✅ Exercise Time
- ✅ Respiratory Rate
- ✅ Oxygen Saturation
- ✅ Workouts

## API Endpoints Used

- `POST /api/health/sync` - Bulk upload health data
- `GET /api/health/sleep/:date` - Get sleep data
- `GET /api/health/summary` - Get health summary

## Next Steps

1. Test the integration on a physical device
2. Add error handling and retry logic
3. Implement background sync
4. Add sync status indicators in UI
5. Handle token refresh automatically

