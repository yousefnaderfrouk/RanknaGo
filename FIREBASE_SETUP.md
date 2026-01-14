# Firebase Setup Instructions

## الخطوات المطلوبة لإعداد Firebase

### 1. تثبيت Node.js Dependencies
```bash
npm install
```

### 2. تشغيل السكريبت لإعداد Firestore
```bash
npm run setup
```
أو
```bash
node setup_firebase.js
```

### 3. رفع Firestore Rules
قم برفع ملف `firestore.rules` إلى Firebase Console:
- اذهب إلى Firebase Console
- اختر مشروع `raknago-pro`
- اذهب إلى Firestore Database
- اضغط على Rules
- انسخ محتوى `firestore.rules` والصقه
- اضغط Publish

أو استخدم Firebase CLI:
```bash
firebase deploy --only firestore:rules
```

### 4. تفعيل Authentication في Firebase Console
1. اذهب إلى Firebase Console
2. اختر مشروع `raknago-pro`
3. اذهب إلى Authentication
4. اضغط على Get Started
5. في Sign-in method، فعّل:
   - Email/Password
   - Google

### 5. إضافة SHA-1 و SHA-256
1. في Firebase Console، اذهب إلى Project Settings
2. في قسم "Your apps"، اختر تطبيق Android
3. أضف SHA-1 و SHA-256:
   - SHA1: `FC:31:89:3B:C8:C6:CE:AB:2D:5A:E5:63:5C:5D:25:90:6C:0E:37:78`
   - SHA-256: `2E:2F:81:F1:25:6C:BB:81:12:A5:B9:3E:95:96:3A:DD:0E:8D:B3:46:CD:5F:98:F4:53:2A:59:D4:03:D0:90:AD`

### 6. Collections التي سيتم إنشاؤها
- `users` - بيانات المستخدمين
- `parking_spots` - مواقف السيارات
- `reservations` - الحجوزات

### 7. تشغيل التطبيق
```bash
flutter pub get
flutter run
```

## الملفات المهمة
- `setup_firebase.js` - سكريبت لإعداد Firestore
- `firestore.rules` - قواعد الأمان لـ Firestore
- `raknago-pro-firebase-adminsdk-fbsvc-01ae84e6ba.json` - Firebase Admin SDK credentials
- `android/app/google-services.json` - Firebase config للـ Android


































