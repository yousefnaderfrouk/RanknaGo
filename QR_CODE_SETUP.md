# QR Code Scanner Setup Guide

## Overview
The QR Scanner system allows users to unlock parking spots by scanning QR codes. The system verifies that the user has an active booking before granting access.

## How It Works

### 1. QR Code Format
Each parking spot should have a unique QR code containing its spot ID. The QR code can be in one of these formats:
- Simple: `spotId` (e.g., `spot_123`)
- Prefixed: `parking_spot_id:spotId` (e.g., `parking_spot_id:spot_123`)

### 2. Verification Process
When a user scans a QR code:
1. ✅ **Authentication Check** - Verify user is logged in
2. ✅ **Parking Spot Check** - Verify the spot exists in Firestore
3. ✅ **Booking Check** - Verify user has an active booking for this specific spot
4. ✅ **Unlock** - If all checks pass, grant access and log the unlock event

### 3. Security Features
- ❌ Users **cannot** unlock parking spots they haven't booked
- ✅ Only spots with **active** bookings can be unlocked
- ✅ Each unlock is logged with timestamp and count
- ✅ Real-time verification against Firestore database

## Creating QR Codes for Parking Spots

### Method 1: Using Online QR Generator
1. Go to any QR code generator (e.g., https://www.qr-code-generator.com/)
2. Enter the spot ID (e.g., `spot_123`)
3. Download and print the QR code
4. Place it at the parking spot entrance

### Method 2: Using Flutter Package (qr_flutter)
Already installed in this project. You can create a QR code generation screen:

```dart
import 'package:qr_flutter/qr_flutter.dart';

QrImageView(
  data: 'spot_123', // Your spot ID
  version: QrVersions.auto,
  size: 200.0,
)
```

### Method 3: Bulk Generation Script
For generating multiple QR codes at once, you can use Python:

```python
import qrcode
import firebase_admin
from firebase_admin import firestore

# Initialize Firebase
cred = firebase_admin.credentials.Certificate('path/to/serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Get all parking spots
spots = db.collection('parking_spots').get()

for spot in spots:
    spot_id = spot.id
    
    # Generate QR code
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(spot_id)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    img.save(f"qr_codes/{spot_id}.png")
    
    print(f"Generated QR code for {spot_id}")
```

## Firestore Data Structure

### Required Collections

#### parking_spots
```javascript
{
  "name": "Parking Spot Name",
  "address": "123 Main St",
  "location": {
    "lat": 30.0444,
    "lng": 31.2357
  },
  // ... other fields
}
```

#### reservations
```javascript
{
  "userId": "user123",
  "spotId": "spot_123",
  "status": "active", // Must be "active" for unlock
  "startTime": Timestamp,
  "endTime": Timestamp,
  "lastUnlocked": Timestamp, // Updated on each unlock
  "unlockCount": 5, // Incremented on each unlock
  // ... other fields
}
```

## Testing

### Test Scenario 1: Valid Booking
1. Create a booking for a parking spot
2. Scan the QR code of that spot
3. ✅ Expected: Success message and unlock

### Test Scenario 2: No Booking
1. Don't create any booking
2. Scan any parking spot QR code
3. ❌ Expected: Error - "No Booking Found"

### Test Scenario 3: Invalid QR Code
1. Scan a random QR code (not a parking spot)
2. ❌ Expected: Error - "Invalid QR Code"

## Logs
The system provides detailed logs for debugging:
- 🔍 QR code scanning events
- ✅ Verification steps
- ❌ Error details
- 📝 Unlock events

Check the console for these emoji-prefixed logs.

## Troubleshooting

### Camera Permission Issues
- Ensure camera permissions are granted in AndroidManifest.xml and Info.plist
- The app will show an error if permissions are denied

### QR Code Not Detected
- Ensure good lighting
- Hold phone steady
- QR code should be clear and not damaged

### "No Booking Found" Error
- Verify the booking exists in Firestore
- Check that booking status is "active" (not "completed" or "cancelled")
- Verify spotId matches exactly

### Database Access Issues
- Check Firestore security rules allow reading bookings
- Ensure user is authenticated

## Future Enhancements
- [ ] Add QR code generation screen in admin panel
- [ ] Support for temporary guest access codes
- [ ] Time-based unlock restrictions
- [ ] Unlock history viewer


