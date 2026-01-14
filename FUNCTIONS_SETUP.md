# Firebase Cloud Functions Setup

## إعداد Cloud Functions لإرسال OTP عبر البريد الإلكتروني

### 1. تثبيت Dependencies

```bash
cd functions
npm install
```

### 2. إعداد Email Configuration

#### الطريقة 1: استخدام Firebase Config (موصى به)

```bash
firebase functions:config:set email.user="your-email@gmail.com" email.password="your-app-password"
```

**ملاحظة:** إذا كنت تستخدم Gmail، يجب إنشاء App Password:
1. اذهب إلى Google Account Settings
2. Security > 2-Step Verification > App passwords
3. أنشئ App Password جديد
4. استخدمه في `email.password`

#### الطريقة 2: استخدام Environment Variables

في `functions/index.js`، يمكنك استخدام `process.env.EMAIL_USER` و `process.env.EMAIL_PASSWORD`

### 3. Deploy Cloud Function

```bash
firebase deploy --only functions
```

### 4. اختبار Cloud Function

بعد الـ deploy، يمكنك اختبار الـ function من Firebase Console:
- اذهب إلى Firebase Console > Functions
- اختر `sendOTPEmail`
- اضغط "Test" وأدخل البيانات:
  ```json
  {
    "email": "test@example.com",
    "otp": "123456"
  }
  ```

### 5. استخدام Cloud Function في Flutter

الكود في `lib/two_factor_auth_screen.dart` يستدعي Cloud Function تلقائياً عند إرسال OTP.

## ملاحظات مهمة:

1. **Email Service**: حالياً الكود يستخدم Gmail. يمكنك تغييره لخدمة أخرى مثل SendGrid أو Mailgun.

2. **Security**: تأكد من أن `email.password` محمي ولا يتم مشاركته.

3. **Costs**: Cloud Functions لها free tier محدود. تحقق من [Firebase Pricing](https://firebase.google.com/pricing).

4. **Testing**: في حالة فشل Cloud Function، سيتم عرض OTP في SnackBar كـ fallback.

## استكشاف الأخطاء:

- إذا فشل إرسال البريد، تحقق من:
  - Email credentials صحيحة
  - App Password صحيح (لـ Gmail)
  - Cloud Function تم deploy بنجاح
  - Firebase project متصل بشكل صحيح

































