# إعداد SMTP لإرسال البريد الإلكتروني

## المشكلة: البريد الإلكتروني لا يصل

إذا كان البريد الإلكتروني لا يصل، اتبع الخطوات التالية:

## خطوات إعداد Gmail App Password

### 1. تفعيل التحقق بخطوتين (2-Step Verification)

1. اذهب إلى [Google Account Security](https://myaccount.google.com/security)
2. في قسم "Signing in to Google"، اضغط على "2-Step Verification"
3. اتبع الخطوات لتفعيل التحقق بخطوتين

### 2. إنشاء App Password

1. بعد تفعيل التحقق بخطوتين، اذهب إلى [App Passwords](https://myaccount.google.com/apppasswords)
2. اختر "Mail" كالتطبيق
3. اختر "Other (Custom name)" كالجهاز
4. أدخل اسم مثل "RaknaGo App"
5. اضغط "Generate"
6. انسخ كلمة المرور المكونة من 16 حرفاً (بدون مسافات)

### 3. تحديث الكود

افتح الملفات التالية وحدّث `smtpPassword`:

- `lib/services/auth_service.dart` (سطر 250-251)
- `lib/two_factor_auth_screen.dart` (سطر 86-87)

استبدل:
```dart
const String smtpPassword = 'vpshkbealjzhqfsm';
```

بكلمة المرور الجديدة التي حصلت عليها.

## ملاحظات مهمة

1. **لا تستخدم كلمة مرور Gmail العادية** - يجب استخدام App Password
2. **تأكد من نسخ كلمة المرور بدون مسافات** - App Password هو 16 حرفاً متتالياً
3. **تحقق من صحة عنوان البريد الإلكتروني** - تأكد أن `smtpUsername` صحيح
4. **تحقق من صندوق Spam** - قد يذهب البريد إلى Spam folder

## اختبار الإعداد

بعد تحديث الكود:

1. شغّل التطبيق
2. جرّب إرسال بريد (مثل reset password أو 2FA)
3. تحقق من Console logs للأخطاء
4. تحقق من صندوق البريد (Inbox و Spam)

## رسائل الخطأ الشائعة

### "Authentication failed" أو "535"
- **الحل**: تأكد من استخدام App Password وليس كلمة المرور العادية
- تأكد من تفعيل 2-Step Verification

### "Connection timeout"
- **الحل**: تحقق من الاتصال بالإنترنت
- قد تكون هناك مشكلة في Firewall

### "Email rejected" أو "550"
- **الحل**: تحقق من صحة عنوان البريد الإلكتروني المستلم
- قد يكون البريد في Spam folder

## بدائل مجانية أخرى

إذا استمرت المشكلة مع Gmail، يمكنك استخدام:

1. **SendGrid** (Free tier: 100 email/day)
2. **Mailgun** (Free tier: 5,000 email/month)
3. **SMTP2GO** (Free tier: 1,000 email/month)

لكن Gmail هو الأسهل والأكثر موثوقية للاستخدام المجاني.
























