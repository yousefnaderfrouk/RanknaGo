@echo off
echo ========================================
echo نشر صفحة التحقق من البريد الإلكتروني
echo ========================================
echo.

echo [1/2] رفع Firestore Rules...
firebase deploy --only firestore:rules --project raknago-pro
if %errorlevel% neq 0 (
    echo.
    echo خطأ في رفع Firestore Rules!
    echo تأكد من أنك مسجل دخول: firebase login
    pause
    exit /b 1
)

echo.
echo [2/2] نشر صفحة التحقق على Firebase Hosting...
firebase deploy --only hosting --project raknago-pro
if %errorlevel% neq 0 (
    echo.
    echo خطأ في نشر Hosting!
    echo تأكد من أنك مسجل دخول: firebase login
    pause
    exit /b 1
)

echo.
echo ========================================
echo تم النشر بنجاح! ✅
echo ========================================
echo.
echo رابط الصفحة:
echo https://raknago-pro.firebaseapp.com/verify-email
echo ========================================
pause

































