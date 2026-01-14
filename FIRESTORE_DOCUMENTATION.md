# Firestore Rules & Collections Documentation

## 📋 Collections Overview

### 1. **users** Collection

#### Schema:
```javascript
{
  email: string (required),
  name: string (required),
  createdAt: timestamp (required),
  updatedAt: timestamp (required),
  phoneNumber: string (optional),
  photoURL: string (optional),
  isEmailVerified: boolean (required, default: false),
  profileCompleted: boolean (required, default: false),
  gender: string (optional: "Male", "Female", "Other"),
  dateOfBirth: string (optional: ISO8601 date string),
  role: string (required, default: "user", values: "user", "admin"),
  status: string (required, default: "active", values: "active", "blocked"),
  streetAddress: string (optional),
  country: string (optional),
  biometricID: boolean (optional, default: false),
  faceID: boolean (optional, default: false),
  smsAuthenticator: boolean (optional, default: false),
  googleAuthenticator: boolean (optional, default: false),
  language: string (optional, default: "English (US)")
}
```

#### Rules:
- **Read**: Users can read their own data, admins can read all
- **Create**: Users can create their own document (must include: email, name, createdAt, updatedAt, isEmailVerified)
- **Update**: Users can update their own data (cannot change email or createdAt), admins can update any user
- **Delete**: Only admins can delete users

---

### 2. **parking_spots** Collection

#### Schema:
```javascript
{
  name: string (required),
  description: string (optional),
  address: string (required),
  location: object (required, {lat: number, lng: number}),
  totalSpots: number (required),
  availableSpots: number (required),
  pricePerHour: number (required),
  hasEVCharging: boolean (optional, default: false),
  evChargingPrice: number (optional, default: 0.0),
  evChargerCount: number (optional, default: 0),
  rating: number (optional, default: 0.0),
  reviewCount: number (optional, default: 0),
  amenities: array<string> (optional),
  isActive: boolean (required, default: true),
  createdAt: timestamp (required),
  updatedAt: timestamp (required)
}
```

#### Rules:
- **Read**: Anyone can read parking spots (public)
- **Create**: Only authenticated users with completed profile or admins
- **Update**: Only authenticated users or admins
- **Delete**: Only authenticated users or admins

---

### 3. **reservations** Collection

#### Schema:
```javascript
{
  userId: string (required),
  spotId: string (required),
  startTime: timestamp (required),
  endTime: timestamp (required),
  duration: string (required, e.g., "2 hours"),
  price: number (required),
  status: string (required, values: "active", "completed", "cancelled"),
  createdAt: timestamp (required),
  updatedAt: timestamp (required)
}
```

#### Rules:
- **Read**: Users can read their own reservations, admins can read all
- **Create**: Users with completed profile can create their own reservations, admins can create any
- **Update**: Users can update their own reservations, admins can update any
- **Delete**: Users can delete their own reservations, admins can delete any

---

## 🔒 Security Rules Summary

### Helper Functions:
1. **isAuthenticated()**: Checks if user is logged in
2. **isOwner(userId)**: Checks if user owns the document
3. **isAdmin()**: Checks if user has admin role

### Key Security Features:
- ✅ Email and createdAt fields cannot be modified by users
- ✅ Profile completion required for creating parking spots and reservations
- ✅ Admin users have full access to all collections
- ✅ Users can only access their own data (except parking spots which are public read)
- ✅ All updates require `updatedAt` timestamp

---

## 📝 Important Notes

1. **User Creation**: When a user signs up, the following fields are automatically set:
   - `role`: "user" (default)
   - `status`: "active" (default)
   - `profileCompleted`: false
   - `isEmailVerified`: false

2. **Reservations Field Names**:
   - Uses `spotId` (not `parkingSpotId`)
   - Uses `price` (not `totalPrice`)

3. **Parking Spots Location**:
   - Uses `location` object with `lat` and `lng` (not `latitude` and `longitude`)

4. **Admin Access**:
   - Admins can read, create, update, and delete any document in all collections
   - Admins can update user `role` and `status` fields

5. **Settings Collection**:
   - Document ID: `app` (single document for app settings)
   - Contains: `commissionRate`, `paymentMethods`, `notifications`, `appVersion`, `paymobSettings`
   - New fields: `developerInfo` (developer contact details and social media)
   - New fields: `aboutInfo` (app name, version, website, job vacancies, partner info, accessibility, terms of use, social media links)
   - Anyone can read settings (public read)
   - Only admins can create/update/delete settings

---

## 🚀 Setup Instructions

1. Run the setup script:
   ```bash
   npm run setup
   ```
   or
   ```bash
   node setup_firebase.js
   ```

2. Deploy Firestore Rules:
   ```bash
   firebase deploy --only firestore:rules --project raknago-pro
   ```

3. Verify collections are created in Firebase Console

---

## ✅ Validation Checklist

- [x] Users collection schema matches code usage
- [x] Parking spots collection schema matches code usage
- [x] Reservations collection schema matches code usage
- [x] Rules allow all required operations
- [x] Rules prevent unauthorized access
- [x] Admin functions work correctly
- [x] Profile completion requirement enforced
- [x] Field names consistent across codebase






