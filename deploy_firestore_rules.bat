@echo off
echo Deploying Firestore Rules...
firebase deploy --only firestore:rules --project raknago-pro
echo Done!
pause





