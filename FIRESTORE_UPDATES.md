# 🔄 تحديثات Firestore Rules والـ Collections

## 📋 ملخص التحديثات

تم تحديث قواعد Firestore لدعم الصفحات الجديدة والحقول المضافة.

---

## ✅ التحديثات على Collections الموجودة

### 1. **users Collection** - حقول جديدة

#### الحقول المضافة:
- `streetAddress` (string, optional) - عنوان الشارع من Personal Info Screen
- `country` (string, optional) - الدولة من Personal Info Screen
- `biometricID` (boolean, optional) - تفعيل البصمة من Security Screen
- `faceID` (boolean, optional) - تفعيل Face ID من Security Screen
- `smsAuthenticator` (boolean, optional) - تفعيل SMS Authenticator من Security Screen
- `googleAuthenticator` (boolean, optional) - تفعيل Google Authenticator من Security Screen
- `language` (string, optional) - اللغة المختارة من Language Screen

#### Rules:
- ✅ المستخدمون يمكنهم تحديث هذه الحقول في بياناتهم
- ✅ الأدمن يمكنه تحديث أي حقل لأي مستخدم

---

### 2. **parking_spots Collection** - حقول جديدة

#### الحقول المضافة:
- `rating` (number, optional, default: 0.0) - التقييم من 0.0 إلى 5.0
- `reviewCount` (number, optional, default: 0) - عدد التقييمات
- `amenities` (array<string>, optional) - قائمة الخدمات المتاحة
  - القيم المحتملة: `['restaurant', 'shopping', 'wifi', 'accessible']`
- `evChargerCount` (number, optional, default: 0) - عدد الشواحن الكهربائية

#### Rules:
- ✅ القواعد الحالية تدعم هذه الحقول (تحديث مسموح للمستخدمين المصادق عليهم والأدمن)

---

## 🆕 Collections جديدة

### 3. **app_info Collection**

**الوصف**: محتوى ديناميكي لصفحة About Screen (يمكن للأدمن إدارته)

**Schema**:
```javascript
{
  // Document ID: 'about'
  developer: {
    name: string,
    email: string,
    website: string,
    location: string
  },
  jobVacancies: array<{
    title: string,
    type: string, // 'Full-time', 'Part-time', etc.
    location: string, // 'Remote', 'On-site', 'Hybrid'
  }>,
  partners: {
    email: string,
    description: string
  },
  accessibility: {
    features: array<string>
  },
  termsOfUse: string,
  socialMedia: {
    facebook: string,
    instagram: string,
    twitter: string,
    linkedin: string
  },
  website: string,
  updatedAt: timestamp
}
```

**Rules**:
- ✅ **Read**: أي شخص يمكنه القراءة (public)
- ✅ **Create/Update/Delete**: الأدمن فقط

---

### 4. **feedback Collection**

**الوصف**: تقييمات المستخدمين من About Screen

**Schema**:
```javascript
{
  userId: string (required),
  feedback: string (required),
  createdAt: timestamp (required)
}
```

**Rules**:
- ✅ **Read**: المستخدم يقرأ تقييمه فقط، الأدمن يقرأ الكل
- ✅ **Create**: المستخدمون المصادق عليهم يمكنهم إنشاء تقييماتهم
- ✅ **Update/Delete**: الأدمن فقط

---

### 5. **ratings Collection**

**الوصف**: تقييمات التطبيق من About Screen (Rate Us)

**Schema**:
```javascript
{
  userId: string (required),
  rating: number (required, 1-5),
  comment: string (optional),
  createdAt: timestamp (required),
  updatedAt: timestamp (optional)
}
```

**Rules**:
- ✅ **Read**: المستخدم يقرأ تقييمه فقط، الأدمن يقرأ الكل
- ✅ **Create**: المستخدمون المصادق عليهم يمكنهم إنشاء تقييماتهم
- ✅ **Update**: المستخدم يعدل تقييمه فقط، الأدمن يعدل أي تقييم
- ✅ **Delete**: الأدمن فقط

---

### 6. **contact_messages Collection**

**الوصف**: رسائل التواصل من Help Center Screen

**Schema**:
```javascript
{
  userId: string (required),
  subject: string (required),
  message: string (required),
  type: string (optional), // 'whatsapp', 'instagram', 'facebook', 'twitter', 'website'
  createdAt: timestamp (required),
  status: string (optional, default: 'pending'), // 'pending', 'read', 'replied'
  repliedAt: timestamp (optional)
}
```

**Rules**:
- ✅ **Read**: المستخدم يقرأ رسائله فقط، الأدمن يقرأ الكل
- ✅ **Create**: المستخدمون المصادق عليهم يمكنهم إنشاء رسائلهم
- ✅ **Update/Delete**: الأدمن فقط

---

### 7. **settings Collection**

**الوصف**: إعدادات التطبيق (موجودة مسبقاً في admin_settings_screen)

**Schema**:
```javascript
{
  // Document ID: 'app'
  commissionRate: number,
  paymentMethods: {
    creditCard: boolean,
    fawry: boolean,
    vodafoneCash: boolean,
    paypal: boolean,
    paymob: boolean // جديد
  },
  notifications: {
    push: boolean,
    email: boolean,
    sms: boolean
  },
  appVersion: string,
  paymobSettings: { // جديد
    apiKey: string,
    integrationId: string,
    iframeId: string
  },
  developerInfo: { // جديد - معلومات المطور
    name: string,
    email: string,
    phone: string,
    website: string,
    location: string,
    socialMedia: {
      facebook: string,
      instagram: string,
      twitter: string,
      linkedin: string
    }
  },
  aboutInfo: { // جديد - معلومات صفحة About
    appName: string,
    appVersion: string,
    website: string,
    jobVacancy: {
      title: string,
      description: string,
      contactEmail: string,
      jobs: array<{title: string, details: string}>
    },
    partnerInfo: {
      title: string,
      description: string,
      contactEmail: string,
      benefits: array<string>
    },
    accessibilityInfo: {
      title: string,
      description: string,
      features: array<string>
    },
    termsInfo: {
      lastUpdated: string,
      sections: array<{title: string, content: string}>
    },
    socialMedia: {
      facebook: string,
      instagram: string,
      twitter: string,
      linkedin: string
    }
  },
  updatedAt: timestamp
}
```

**Rules**:
- ✅ **Read**: أي شخص يمكنه القراءة (public)
- ✅ **Create/Update/Delete**: الأدمن فقط

---

### 8. **system_logs Collection**

**الوصف**: سجلات أنشطة الأدمن (موجودة مسبقاً)

**Schema**:
```javascript
{
  action: string (required),
  userId: string (optional),
  timestamp: timestamp (required),
  details: object (optional)
}
```

**Rules**:
- ✅ **Read**: الأدمن فقط
- ✅ **Create**: الأدمن فقط
- ✅ **Delete**: الأدمن فقط

---

## 📝 ملاحظات مهمة

### الحقول الجديدة في users:
- `streetAddress` و `country` - من Personal Info Screen
- `biometricID`, `faceID`, `smsAuthenticator`, `googleAuthenticator` - من Security Screen
- جميعها optional ويمكن للمستخدمين تحديثها

### الحقول الجديدة في parking_spots:
- `rating`, `reviewCount`, `amenities`, `evChargerCount` - يمكن للأدمن إضافتها/تعديلها
- `amenities` هو array من strings

### Collections جديدة:
- جميعها تحتاج إلى إنشاء من الأدمن أول مرة
- `app_info` collection يجب أن يحتوي على document واحد باسم `about`
- `settings` collection يجب أن يحتوي على document واحد باسم `app`

---

## 🚀 خطوات التطبيق

1. **ارفع Rules إلى Firebase**:
   ```bash
   firebase deploy --only firestore:rules --project raknago-pro
   ```

2. **أنشئ Collections الجديدة** (اختياري - ستنشأ تلقائياً عند أول استخدام):
   - `app_info`
   - `feedback`
   - `ratings`
   - `contact_messages`

3. **أنشئ Document في app_info**:
   - Document ID: `about`
   - يمكن للأدمن إدارته من Admin Settings Screen

---

## ✅ Checklist

- [x] تحديث rules لدعم الحقول الجديدة في users
- [x] إضافة rules لـ app_info collection
- [x] إضافة rules لـ feedback collection
- [x] إضافة rules لـ ratings collection
- [x] إضافة rules لـ contact_messages collection
- [x] إضافة rules لـ settings collection
- [x] إضافة rules لـ system_logs collection
- [x] جميع القواعد تدعم الصفحات الجديدة

---

## 📊 استخدام Collections في الكود

### users (حقول جديدة):
- `lib/new home/personal_info_screen.dart` - streetAddress, country
- `lib/new home/security_screen.dart` - biometricID, faceID, smsAuthenticator, googleAuthenticator

### parking_spots (حقول جديدة):
- `lib/admin/manage_parking_spots_screen.dart` - rating, reviewCount, amenities, evChargerCount
- `lib/home_screen.dart` - قراءة وعرض الحقول الجديدة

### settings (حقول جديدة):
- `lib/admin/admin_settings_screen.dart` - إدارة developerInfo و aboutInfo
- `lib/new home/about_screen.dart` - قراءة وعرض developerInfo و aboutInfo

### feedback:
- `lib/new home/about_screen.dart` - إرسال feedback (يحتاج تحديث)

### ratings:
- `lib/new home/about_screen.dart` - إرسال تقييمات (يحتاج تحديث)

### contact_messages:
- `lib/new home/help_center_screen.dart` - إرسال رسائل (يحتاج تحديث)

---

## ⚠️ ملاحظات

1. **الصفحات الجديدة**:
   - ✅ `about_screen.dart` - تم ربطه بـ Firestore (يقرأ من settings/app/aboutInfo و developerInfo)
   - ✅ `help_center_screen.dart` - تم تفعيل الأزرار وإضافة أسئلة أكثر
   - ✅ `security_screen.dart` - يحفظ الإعدادات في Firestore
   - ✅ `personal_info_screen.dart` - يحفظ البيانات في Firestore

2. **Admin Settings**:
   - ✅ تم إضافة قسم لإدارة `developerInfo` في `settings/app`
   - ✅ تم إضافة قسم لإدارة `aboutInfo` في `settings/app`

3. **الحقول الاختيارية**:
   - جميع الحقول الجديدة optional، لذا لن تسبب مشاكل مع البيانات الموجودة

