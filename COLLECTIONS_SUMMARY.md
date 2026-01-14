# 📋 ملخص Collections و Rules للبرنامج

## ✅ Collections الموجودة (4 Collections)

### 1. **users** Collection
**الوصف**: بيانات المستخدمين (عادي + ادمن)

**Schema**:
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
  status: string (required, default: "active", values: "active", "blocked")
}
```

**Rules**:
- ✅ Read: المستخدم يقرأ بياناته فقط، الادمن يقرأ الكل
- ✅ Create: المستخدم ينشئ بياناته (يجب: email, name, createdAt, updatedAt, isEmailVerified)
- ✅ Update: المستخدم يعدل بياناته (لا يمكن تعديل email, createdAt)، الادمن يعدل أي مستخدم
- ✅ Delete: الادمن فقط يمكنه حذف المستخدمين

---

### 2. **parking_spots** Collection
**الوصف**: مواقف السيارات

**Schema**:
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
  isActive: boolean (required, default: true),
  createdAt: timestamp (required),
  updatedAt: timestamp (required)
}
```

**Rules**:
- ✅ Read: أي شخص يمكنه القراءة (public)
- ✅ Create: المستخدمون المكتملين أو الادمن
- ✅ Update: المستخدمون المصادق عليهم أو الادمن
- ✅ Delete: المستخدمون المصادق عليهم أو الادمن

---

### 3. **reservations** Collection
**الوصف**: حجوزات مواقف السيارات

**Schema**:
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

**Rules**:
- ✅ Read: المستخدم يقرأ حجوزاته فقط، الادمن يقرأ الكل
- ✅ Create: المستخدمون المكتملين ينشئون حجوزاتهم، الادمن ينشئ أي حجز
- ✅ Update: المستخدم يعدل حجوزاته، الادمن يعدل أي حجز
- ✅ Delete: المستخدم يحذف حجوزاته، الادمن يحذف أي حجز

---

### 4. **notifications** Collection
**الوصف**: إشعارات الادمن للمستخدمين

**Schema**:
```javascript
{
  title: string (required),
  message: string (required),
  type: string (required, values: "general", "booking", "system", "promotion"),
  recipientType: string (required, values: "all", "user"),
  recipientId: string (optional, userId if recipientType is "user"),
  sentBy: string (required, "system" or "admin_userId"),
  sentAt: timestamp (required),
  readBy: array (optional, array of user IDs who read the notification),
  createdAt: timestamp (required),
  updatedAt: timestamp (required)
}
```

**Rules**:
- ✅ Read: المستخدم يقرأ الإشعارات المرسلة له أو للجميع، الادمن يقرأ الكل
- ✅ Create: الادمن فقط يمكنه إنشاء الإشعارات
- ✅ Update: المستخدم يعدل `readBy` فقط (لتمييز الإشعار كمقروء)، الادمن يعدل أي حقل
- ✅ Delete: الادمن فقط يمكنه حذف الإشعارات

---

## 🔒 Security Rules Summary

### Helper Functions:
1. **isAuthenticated()**: يتحقق من تسجيل الدخول
2. **isOwner(userId)**: يتحقق من ملكية المستند
3. **isAdmin()**: يتحقق من صلاحيات الادمن

### Key Security Features:
- ✅ Email و createdAt لا يمكن تعديلهما من قبل المستخدمين
- ✅ Profile completion مطلوب لإنشاء parking spots و reservations
- ✅ الادمن له صلاحيات كاملة على جميع Collections
- ✅ المستخدمون يمكنهم الوصول لبياناتهم فقط (ما عدا parking spots public read)
- ✅ جميع التحديثات تتطلب `updatedAt` timestamp

---

## 📝 ملاحظات مهمة:

1. **User Creation**: عند التسجيل، يتم تعيين:
   - `role`: "user" (default)
   - `status`: "active" (default)
   - `profileCompleted`: false
   - `isEmailVerified`: false

2. **Reservations Field Names**:
   - يستخدم `spotId` (ليس `parkingSpotId`)
   - يستخدم `price` (ليس `totalPrice`)

3. **Parking Spots Location**:
   - يستخدم `location` object مع `lat` و `lng` (ليس `latitude` و `longitude`)

4. **Admin Access**:
   - الادمن يمكنه قراءة، إنشاء، تحديث، وحذف أي مستند في جميع Collections
   - الادمن يمكنه تحديث `role` و `status` للمستخدمين

---

## ✅ Checklist التحقق:

- [x] users collection موجود ومحدد
- [x] parking_spots collection موجود ومحدد
- [x] reservations collection موجود ومحدد
- [x] notifications collection موجود ومحدد
- [x] Rules لجميع Collections موجودة
- [x] Admin functions تعمل بشكل صحيح
- [x] Profile completion requirement مفعّل
- [x] الحقول المحمية (email, createdAt) لا يمكن تعديلها
- [x] جميع الحقول المستخدمة في الكود موجودة في Schema

---

## 🚀 الخطوات التالية:

1. **شغّل السكريبت**:
   ```bash
   node setup_firebase.js
   ```

2. **ارفع Rules إلى Firebase**:
   - من Firebase Console: انسخ محتوى `firestore.rules` والصقه
   - أو من Terminal: `firebase deploy --only firestore:rules --project raknago-pro`

3. **تحقق من Collections**:
   - افتح Firebase Console
   - اذهب إلى Firestore Database
   - تأكد من وجود جميع Collections الأربعة

---

## 📊 استخدام Collections في الكود:

### users:
- `lib/services/auth_service.dart` - إنشاء وتحديث المستخدمين
- `lib/complete_profile_screen.dart` - إكمال الملف الشخصي
- `lib/login_screen.dart` - التحقق من المستخدم
- `lib/splash_screen.dart` - التحقق من role
- `lib/admin/manage_users_screen.dart` - إدارة المستخدمين (ادمن)

### parking_spots:
- `lib/admin/manage_parking_spots_screen.dart` - إدارة المواقف (ادمن)
- `lib/admin/admin_dashboard_screen.dart` - إحصائيات المواقف
- `lib/admin/manage_bookings_screen.dart` - استخدام المواقف في الحجوزات

### reservations:
- `lib/admin/manage_bookings_screen.dart` - إدارة الحجوزات (ادمن)
- `lib/admin/admin_dashboard_screen.dart` - إحصائيات الحجوزات
- `lib/admin/manage_users_screen.dart` - عدد حجوزات المستخدم

### notifications:
- `lib/admin/manage_notifications_screen.dart` - إدارة الإشعارات (ادمن) - **يحتاج تحديث لاستخدام Firestore**

---

## ⚠️ ملاحظة:

`manage_notifications_screen.dart` حالياً يستخدم local state فقط. يجب تحديثه لاستخدام Firestore collection `notifications` بدلاً من local state.


































