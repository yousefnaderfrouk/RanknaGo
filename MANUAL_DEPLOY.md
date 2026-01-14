# دليل رفع Cloud Function يدوياً

## الطريقة 1: من Firebase Console (الأسهل)

### الخطوات:

1. **اذهب إلى Firebase Console**:
   - افتح [Firebase Console](https://console.firebase.google.com/)
   - اختر مشروع `raknago-pro`

2. **اذهب إلى Functions**:
   - من القائمة الجانبية، اضغط على **Functions**
   - إذا لم تكن Functions مفعلة، اضغط **Get Started**

3. **إنشاء Function جديد**:
   - اضغط على **Create function**
   - اختر **Callable function**
   - اسم الـ Function: `sendOTPEmail`
   - Region: `us-central1`
   - Runtime: `Node.js 18`

4. **نسخ الكود**:
   - انسخ محتوى ملف `functions/index.js`
   - الصقه في محرر الكود في Firebase Console

5. **إعداد Environment Variables**:
   - في قسم **Environment variables**، أضف:
     - `EMAIL_USER` = `keroyousf8@gmail.com`
     - `EMAIL_PASSWORD` = `vpshkbealjzhqfsm` (بدون مسافات)

6. **Deploy**:
   - اضغط **Deploy**

---

## الطريقة 2: استخدام Firebase CLI (من Terminal)

### الخطوات:

1. **تأكد من أنك في مجلد المشروع**:
   ```bash
   cd "D:\Work\Flutter Project\Rakna\raknago"
   ```

2. **تأكد من تسجيل الدخول**:
   ```bash
   firebase login
   ```

3. **اختر المشروع**:
   ```bash
   firebase use raknago-pro
   ```

4. **اذهب إلى مجلد functions**:
   ```bash
   cd functions
   ```

5. **تثبيت Dependencies**:
   ```bash
   npm install
   ```

6. **ارجع للمجلد الرئيسي**:
   ```bash
   cd ..
   ```

7. **Deploy Function**:
   ```bash
   firebase deploy --only functions:sendOTPEmail --project raknago-pro
   ```

---

## الطريقة 3: استخدام Firebase CLI مع تفاصيل أكثر

### إذا فشل Deploy، جرب:

1. **تحقق من Firebase CLI**:
   ```bash
   firebase --version
   ```

2. **تحقق من تسجيل الدخول**:
   ```bash
   firebase projects:list
   ```

3. **Deploy مع تفاصيل**:
   ```bash
   firebase deploy --only functions --project raknago-pro --debug
   ```

---

## التحقق من نجاح Deploy:

1. **من Firebase Console**:
   - اذهب إلى Functions
   - يجب أن ترى `sendOTPEmail` في القائمة
   - Status يجب أن يكون `Deployed`

2. **من Terminal**:
   ```bash
   firebase functions:list --project raknago-pro
   ```

---

## استكشاف الأخطاء:

### إذا ظهر خطأ "NOT_FOUND":
- تأكد من أن Function تم deployه بنجاح
- تأكد من أن Region صحيح (`us-central1`)
- تأكد من أن اسم Function صحيح (`sendOTPEmail`)

### إذا ظهر خطأ في Email:
- تحقق من App Password (بدون مسافات)
- تحقق من أن البريد الإلكتروني صحيح
- تحقق من Firebase Functions Logs

---

## ملاحظات مهمة:

1. **Region**: يجب أن يكون نفس الـ region في Flutter و Cloud Function
2. **App Password**: يجب أن يكون بدون مسافات
3. **Email**: يجب أن يكون البريد الإلكتروني صحيح

































