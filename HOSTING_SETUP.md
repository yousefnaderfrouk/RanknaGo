# إعداد Firebase Hosting لصفحة التحقق من البريد الإلكتروني

## الخطوات المطلوبة

### 1. تثبيت Firebase CLI (إذا لم يكن مثبتاً)
```bash
npm install -g firebase-tools
```

### 2. تسجيل الدخول إلى Firebase
```bash
firebase login
```

### 3. التأكد من المشروع الصحيح
```bash
firebase use raknago-pro
```

### 4. رفع Firestore Rules المحدثة
```bash
firebase deploy --only firestore:rules
```

### 5. نشر صفحة التحقق من البريد الإلكتروني
```bash
firebase deploy --only hosting
```

## الملفات المطلوبة

- `public/verify-email.html` - صفحة التحقق من البريد الإلكتروني
- `firebase.json` - إعدادات Firebase (تم تحديثه لإضافة hosting)
- `firestore.rules` - قواعد Firestore (تم تحديثها للسماح بالتحقق)

## رابط الصفحة بعد النشر

بعد النشر، ستكون صفحة التحقق متاحة على:
```
https://raknago-pro.firebaseapp.com/verify-email?token=TOKEN&uid=UID
```

## ملاحظات مهمة

1. **Firebase Hosting مجاني تماماً** في Spark plan (الخطة المجانية)
2. لا تحتاج إلى ترقية إلى Blaze plan لاستخدام Hosting
3. الصفحة تستخدم Firebase JavaScript SDK للتحقق من الـ token وتحديث حالة `isEmailVerified`
4. تم تحديث Firestore rules للسماح بتحديث `isEmailVerified` بدون مصادقة عند التحقق من الـ token

## التحقق من النشر

بعد النشر، يمكنك التحقق من أن الصفحة تعمل بشكل صحيح عن طريق:
1. فتح رابط التحقق في المتصفح
2. التحقق من أن الصفحة تعرض رسالة نجاح أو خطأ بشكل صحيح
3. التحقق من أن `isEmailVerified` تم تحديثه في Firestore

































