# إعداد إرسال OTP عبر البريد الإلكتروني

## الخيارات المجانية:

### 1. EmailJS (موصى به - مجاني)

**الخطوات:**

1. **إنشاء حساب**:
   - اذهب إلى [EmailJS](https://www.emailjs.com/)
   - سجّل حساب مجاني (100 email/month مجاني)

2. **إعداد Email Service**:
   - اذهب إلى Email Services
   - اختر Gmail أو أي خدمة بريد
   - اربط حسابك

3. **إنشاء Email Template**:
   - اذهب إلى Email Templates
   - اضغط Create New Template
   - استخدم هذا Template:
     ```
     Subject: Your 2FA Verification Code - RaknaGo
     
     Hello,
     
     Your verification code is: {{otp_code}}
     
     This code will expire in 5 minutes.
     
     If you didn't request this code, please ignore this email.
     
     Thanks,
     RaknaGo Team
     ```

4. **الحصول على Keys**:
   - Service ID: من Email Services
   - Template ID: من Email Templates
   - User ID: من Account Settings > API Keys

5. **تحديث الكود**:
   - افتح `lib/two_factor_auth_screen.dart`
   - ابحث عن `_sendOTPViaEmail`
   - استبدل:
     - `YOUR_SERVICE_ID` بـ Service ID
     - `YOUR_TEMPLATE_ID` بـ Template ID
     - `YOUR_USER_ID` بـ User ID

---

### 2. Mailgun (5000 email/month مجاني)

1. **إنشاء حساب**: [Mailgun](https://www.mailgun.com/)
2. **الحصول على API Key**
3. **تحديث الكود** لاستخدام Mailgun API

---

### 3. SendGrid (100 email/day مجاني)

1. **إنشاء حساب**: [SendGrid](https://sendgrid.com/)
2. **الحصول على API Key**
3. **تحديث الكود** لاستخدام SendGrid API

---

## ملاحظة:

حالياً الكود يستخدم EmailJS. يجب إعداد EmailJS account وتحديث الـ keys في الكود.

































