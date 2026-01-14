# كيفية جعل نفسك Admin

## الطريقة الأولى: استخدام السكريبت (الأسهل)

### 1. تأكد من تثبيت Node.js dependencies
```bash
npm install
```

### 2. شغل السكريبت
```bash
npm run make-admin
```
أو
```bash
node make_admin.js
```

### 3. أدخل البريد الإلكتروني
- السكريبت سيسألك عن البريد الإلكتروني
- أدخل البريد الإلكتروني الخاص بك
- أكد العملية

### 4. سجل خروج وسجل دخول مرة أخرى
- بعد جعل نفسك admin، سجل خروج من التطبيق
- سجل دخول مرة أخرى
- ستظهر لك صفحة Admin Dashboard تلقائياً

---

## الطريقة الثانية: من Firebase Console

### 1. افتح Firebase Console
- اذهب إلى: https://console.firebase.google.com/
- اختر مشروع `raknago-pro`

### 2. اذهب إلى Firestore Database
- من القائمة الجانبية، اختر **Firestore Database**
- اضغط على **Data** tab

### 3. ابحث عن المستخدم
- افتح collection **users**
- ابحث عن المستخدم الخاص بك (بالبريد الإلكتروني)

### 4. عدل المستخدم
- اضغط على document الخاص بك
- اضغط على **Edit document**
- أضف field جديد:
  - **Field name**: `role`
  - **Field type**: `string`
  - **Field value**: `admin`
- اضغط **Update**

### 5. سجل خروج وسجل دخول مرة أخرى
- بعد التعديل، سجل خروج من التطبيق
- سجل دخول مرة أخرى
- ستظهر لك صفحة Admin Dashboard تلقائياً

---

## الطريقة الثالثة: من الكود (للمطورين)

### 1. افتح Firebase Console
- اذهب إلى Firestore Database
- افتح collection **users**
- ابحث عن document الخاص بك

### 2. انسخ User ID
- انسخ الـ document ID (هو الـ User ID)

### 3. استخدم Firebase Admin SDK
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./raknago-pro-firebase-adminsdk-fbsvc-01ae84e6ba.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'raknago-pro'
});

const db = admin.firestore();

// استبدل 'YOUR_USER_ID' بـ User ID الخاص بك
await db.collection('users').doc('YOUR_USER_ID').update({
  role: 'admin',
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

---

## ملاحظات مهمة:

1. **بعد جعل نفسك admin:**
   - يجب تسجيل الخروج والدخول مرة أخرى
   - ستظهر لك صفحة Admin Dashboard تلقائياً

2. **التحقق من أنك admin:**
   - افتح Firestore Database
   - افتح collection **users**
   - افتح document الخاص بك
   - تأكد من وجود field `role` بقيمة `admin`

3. **إذا لم تظهر صفحة Admin:**
   - تأكد من تسجيل الخروج والدخول مرة أخرى
   - تأكد من أن field `role` موجود وقيمته `admin`
   - تأكد من أن document موجود في collection **users**

---

## الأمان:

- **Admin فقط** يمكنه:
  - قراءة جميع بيانات المستخدمين
  - تعديل أي مستخدم
  - حذف المستخدمين
  - إدارة Parking Spots
  - إدارة Bookings
  - قراءة جميع الحجوزات

- **المستخدمين العاديين** يمكنهم فقط:
  - قراءة بياناتهم الخاصة
  - تعديل بياناتهم الخاصة
  - إنشاء Parking Spots (إذا كان profile مكتمل)
  - إنشاء Reservations (إذا كان profile مكتمل)


































