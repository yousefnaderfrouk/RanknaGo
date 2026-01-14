# خطوات نشر صفحة التحقق من البريد الإلكتروني

## ✅ الحل 100% مجاني - لا يحتاج Cloud Functions!

### الخطوة 1: رفع Firestore Rules
```bash
firebase deploy --only firestore:rules --project raknago-pro
```

### الخطوة 2: نشر صفحة التحقق
```bash
firebase deploy --only hosting --project raknago-pro
```

## ملاحظات مهمة:

1. **إذا لم تكن مسجل دخول في Firebase CLI:**
   ```bash
   firebase login
   ```

2. **إذا لم يكن المشروع مضبوط:**
   ```bash
   firebase use raknago-pro
   ```

3. **بعد النشر، ستكون الصفحة متاحة على:**
   ```
   https://raknago-pro.firebaseapp.com/verify-email?token=TOKEN&uid=UID
   ```

## ✅ تأكيد:
- ✅ **لا Cloud Functions** - الحل يستخدم Firebase JavaScript SDK مباشرة
- ✅ **Firebase Hosting مجاني** في Spark plan
- ✅ **SMTP مجاني** (Gmail App Password)
- ✅ **الحل 100% مجاني تماماً!**

































