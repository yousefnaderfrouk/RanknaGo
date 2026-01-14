# خطوات Deploy Cloud Function يدوياً

## الخطوة 1: التحقق من Firebase CLI

```bash
firebase --version
```

إذا لم يكن مثبتاً:
```bash
npm install -g firebase-tools
```

## الخطوة 2: تسجيل الدخول

```bash
firebase login
```

## الخطوة 3: اختيار المشروع

```bash
firebase use raknago-pro
```

## الخطوة 4: تثبيت Dependencies

```bash
cd functions
npm install
cd ..
```

## الخطوة 5: Deploy Function

```bash
firebase deploy --only functions:sendOTPEmail --project raknago-pro
```

## الخطوة 6: التحقق من Deploy

```bash
firebase functions:list --project raknago-pro
```

يجب أن ترى `sendOTPEmail` في القائمة.

## إذا فشل Deploy:

### جرب Deploy جميع Functions:
```bash
firebase deploy --only functions --project raknago-pro
```

### تحقق من Logs:
```bash
firebase functions:log --project raknago-pro
```

### Deploy مع Debug:
```bash
firebase deploy --only functions --project raknago-pro --debug
```

































