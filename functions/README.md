# Firebase Cloud Functions - Email OTP

## إعداد Email Credentials

### الطريقة 1: استخدام Firebase Config (موصى به)

```bash
firebase functions:config:set email.user="your-email@gmail.com" email.password="your-app-password"
```

**ملاحظة مهمة:** إذا كنت تستخدم Gmail:
1. اذهب إلى [Google Account Settings](https://myaccount.google.com/)
2. Security > 2-Step Verification
3. App passwords
4. أنشئ App Password جديد
5. استخدمه في `email.password`

### الطريقة 2: استخدام Environment Variables

يمكنك إعداد environment variables في Firebase Console:
- اذهب إلى Firebase Console > Functions > Configuration
- أضف:
  - `EMAIL_USER`: your-email@gmail.com
  - `EMAIL_PASSWORD`: your-app-password

## Deploy Cloud Function

بعد إعداد email credentials، قم بـ deploy:

```bash
firebase deploy --only functions
```

## اختبار Cloud Function

بعد الـ deploy، يمكنك اختبار الـ function من:
- Firebase Console > Functions > sendOTPEmail > Test
- أو من Flutter app مباشرة

## ملاحظات

- تأكد من أن email credentials صحيحة
- App Password مطلوب لـ Gmail
- Cloud Function سيرسل OTP تلقائياً عند تفعيل 2FA

































