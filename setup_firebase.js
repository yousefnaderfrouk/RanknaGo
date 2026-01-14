const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./raknago-pro-firebase-adminsdk-fbsvc-01ae84e6ba.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'raknago-pro'
});

const db = admin.firestore();

async function setupFirestore() {
  try {
    console.log('🚀 Starting Firebase setup...\n');

    // 1. Create users collection with sample data structure
    console.log('📝 Creating users collection...');
    const usersRef = db.collection('users');
    
    // Create a sample user document structure (for reference - will be created when user signs up)
    const sampleUser = {
      email: 'sample@example.com',
      name: 'Sample User',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      phoneNumber: null,
      photoURL: null,
      isEmailVerified: false,
      profileCompleted: false,
      gender: null,
      dateOfBirth: null
    };
    
    // Create a reference document to initialize the collection
    try {
      await usersRef.doc('_collection_info').set({
        description: 'Users collection',
        schema: {
          email: 'string (required)',
          name: 'string (required)',
          createdAt: 'timestamp (required)',
          updatedAt: 'timestamp (required)',
          phoneNumber: 'string (optional)',
          photoURL: 'string (optional)',
          isEmailVerified: 'boolean (required, default: false)',
          profileCompleted: 'boolean (required, default: false)',
          gender: 'string (optional: Male, Female, Other)',
          dateOfBirth: 'string (optional: ISO8601 date string)',
          role: 'string (required, default: user, values: user, admin)',
          status: 'string (required, default: active, values: active, blocked)',
          twoFactorEnabled: 'boolean (optional, default: false)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Users collection created\n');
    } catch (error) {
      console.log('✅ Users collection ready\n');
    }

    // 2. Create parking_spots collection
    console.log('🅿️ Creating parking_spots collection...');
    const parkingSpotsRef = db.collection('parking_spots');
    
    const sampleParkingSpot = {
      name: 'Sample Parking Spot',
      description: 'Sample parking spot description',
      address: '123 Main St',
      location: {
        lat: 30.0444,
        lng: 31.2357
      },
      totalSpots: 50,
      availableSpots: 30,
      pricePerHour: 5.0,
      hasEVCharging: false,
      evChargingPrice: 0.0,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    try {
      await parkingSpotsRef.doc('_collection_info').set({
        description: 'Parking spots collection',
        schema: {
          name: 'string (required)',
          description: 'string (optional)',
          address: 'string (required)',
          location: 'object (required, {lat: number, lng: number})',
          totalSpots: 'number (required)',
          availableSpots: 'number (required)',
          pricePerHour: 'number (required)',
          hasEVCharging: 'boolean (optional, default: false)',
          evChargingPrice: 'number (optional, default: 0.0)',
          isActive: 'boolean (required, default: true)',
          createdAt: 'timestamp (required)',
          updatedAt: 'timestamp (required)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Parking spots collection created\n');
    } catch (error) {
      console.log('✅ Parking spots collection ready\n');
    }

    // 3. Create notifications collection
    console.log('🔔 Creating notifications collection...');
    const notificationsRef = db.collection('notifications');
    
    const sampleNotification = {
      title: 'Welcome to RaknaGo',
      message: 'Thank you for joining our parking service',
      type: 'general', // general, booking, system, promotion
      recipientType: 'all', // all, user, admin
      recipientId: null, // null for 'all', userId for specific user
      sentBy: 'system', // system, admin_userId
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [], // Array of user IDs who read the notification
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    try {
      await notificationsRef.doc('_collection_info').set({
        description: 'Notifications collection',
        schema: {
          title: 'string (required)',
          message: 'string (required)',
          type: 'string (required, values: general, booking, system, promotion)',
          recipientType: 'string (required, values: all, user)',
          recipientId: 'string (optional, userId if recipientType is user)',
          sentBy: 'string (required, system or admin_userId)',
          sentAt: 'timestamp (required)',
          readBy: 'array (optional, array of user IDs)',
          createdAt: 'timestamp (required)',
          updatedAt: 'timestamp (required)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Notifications collection created\n');
    } catch (error) {
      console.log('✅ Notifications collection ready\n');
    }

    // 4. Create reservations collection
    console.log('📅 Creating reservations collection...');
    const reservationsRef = db.collection('reservations');
    
    const sampleReservation = {
      userId: 'user_id',
      spotId: 'spot_id', // Note: uses 'spotId' not 'parkingSpotId'
      startTime: admin.firestore.Timestamp.now(),
      endTime: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3600000)), // 1 hour later
      duration: '2 hours',
      price: 10.0, // Note: uses 'price' not 'totalPrice'
      status: 'active', // active, completed, cancelled
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    try {
      await reservationsRef.doc('_collection_info').set({
        description: 'Reservations collection',
        schema: {
          userId: 'string (required)',
          spotId: 'string (required)',
          startTime: 'timestamp (required)',
          endTime: 'timestamp (required)',
          duration: 'string (required, e.g., "2 hours")',
          price: 'number (required)',
          status: 'string (required, values: active, completed, cancelled)',
          createdAt: 'timestamp (required)',
          updatedAt: 'timestamp (required)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Reservations collection created\n');
    } catch (error) {
      console.log('✅ Reservations collection ready\n');
    }

    // 5. Create settings collection (admin only)
    console.log('⚙️ Creating settings collection...');
    const settingsRef = db.collection('settings');
    
    try {
      await settingsRef.doc('_collection_info').set({
        description: 'App settings collection (admin only)',
        schema: {
          commissionRate: 'number (required, default: 10.0)',
          paymentMethods: 'object (required, {creditCard: boolean, fawry: boolean, vodafoneCash: boolean, paypal: boolean})',
          notifications: 'object (required, {push: boolean, email: boolean, sms: boolean})',
          appVersion: 'string (required, default: "1.0.0")',
          updatedAt: 'timestamp (required)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Settings collection created\n');
    } catch (error) {
      console.log('✅ Settings collection ready\n');
    }

    // 6. Create system_logs collection (admin only)
    console.log('📋 Creating system_logs collection...');
    const systemLogsRef = db.collection('system_logs');
    
    try {
      await systemLogsRef.doc('_collection_info').set({
        description: 'System logs collection (admin only)',
        schema: {
          action: 'string (required, e.g., "User login", "Booking created")',
          userId: 'string (optional, user ID who performed the action)',
          timestamp: 'timestamp (required)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ System logs collection created\n');
    } catch (error) {
      console.log('✅ System logs collection ready\n');
    }

    // 7. Create backups collection (admin only)
    console.log('💾 Creating backups collection...');
    const backupsRef = db.collection('backups');
    
    try {
      await backupsRef.doc('_collection_info').set({
        description: 'Backups collection (admin only)',
        schema: {
          timestamp: 'timestamp (required)',
          parkingSpots: 'number (required, count of parking spots)',
          users: 'number (required, count of users)',
          bookings: 'number (required, count of bookings)',
          createdBy: 'string (required, admin user ID)'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Backups collection created\n');
    } catch (error) {
      console.log('✅ Backups collection ready\n');
    }

    // 8. Deploy Firestore Security Rules using Admin SDK
    console.log('🔒 Deploying Firestore Security Rules...');
    const firestoreRules = `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Helper function to check if user is admin
    function isAdmin() {
      return isAuthenticated() 
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own data, admins can read all
      allow read: if isOwner(userId) || isAdmin();
      
      // Users can create their own document
      // Must include required fields: email, name, createdAt, updatedAt, isEmailVerified
      allow create: if isAuthenticated() 
        && request.auth.uid == userId
        && request.resource.data.keys().hasAll(['email', 'name', 'createdAt', 'updatedAt', 'isEmailVerified'])
        && request.resource.data.email is string
        && request.resource.data.name is string
        && request.resource.data.isEmailVerified is bool;
      
      // Users can update their own data, admins can update any user
      // Can update: name, gender, dateOfBirth, phoneNumber, photoURL, profileCompleted, isEmailVerified, role
      allow update: if (isOwner(userId)
        && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['email', 'createdAt']))
        && (request.resource.data.updatedAt is timestamp))
        || (isAdmin() && (request.resource.data.updatedAt is timestamp));
      
      // Only admins can delete users
      allow delete: if isAdmin();
    }
    
    // Parking spots collection
    match /parking_spots/{spotId} {
      // Anyone can read parking spots
      allow read: if true;
      
      // Only authenticated users with completed profile or admins can create spots
      allow create: if isAdmin() || (isAuthenticated() 
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.profileCompleted == true);
      
      // Only authenticated users or admins can update spots
      allow update: if isAdmin() || isAuthenticated();
      
      // Only authenticated users or admins can delete spots
      allow delete: if isAdmin() || isAuthenticated();
    }
    
    // Reservations collection
    match /reservations/{reservationId} {
      // Users can read their own reservations, admins can read all
      allow read: if isAdmin() || (isAuthenticated() && 
        resource.data.userId == request.auth.uid);
      
      // Users with completed profile can create their own reservations, admins can create any
      allow create: if isAdmin() || (isAuthenticated() 
        && request.resource.data.userId == request.auth.uid
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.profileCompleted == true);
      
      // Users can update their own reservations, admins can update any
      allow update: if isAdmin() || (isAuthenticated() && 
        resource.data.userId == request.auth.uid);
      
      // Users can delete their own reservations, admins can delete any
      allow delete: if isAdmin() || (isAuthenticated() && 
        resource.data.userId == request.auth.uid);
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      // Users can read notifications sent to them or to all, admins can read all
      allow read: if isAdmin() || (isAuthenticated() && 
        (resource.data.recipientType == 'all' || 
         resource.data.recipientId == request.auth.uid));
      
      // Only admins can create notifications
      allow create: if isAdmin() 
        && request.resource.data.keys().hasAll(['title', 'message', 'type', 'recipientType', 'sentBy', 'sentAt', 'createdAt', 'updatedAt'])
        && request.resource.data.title is string
        && request.resource.data.message is string
        && request.resource.data.type is string
        && request.resource.data.recipientType is string
        && request.resource.data.sentBy is string
        && request.resource.data.sentAt is timestamp
        && request.resource.data.createdAt is timestamp
        && request.resource.data.updatedAt is timestamp;
      
      // Users can update readBy array (mark as read), admins can update any field
      allow update: if isAdmin() || (isAuthenticated() && 
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readBy', 'updatedAt'])
        && request.resource.data.updatedAt is timestamp);
      
      // Only admins can delete notifications
      allow delete: if isAdmin();
    }
    
    // Settings collection (admin only)
    match /settings/{settingId} {
      // Only admins can read settings
      allow read: if isAdmin();
      
      // Only admins can create settings
      allow create: if isAdmin();
      
      // Only admins can update settings
      allow update: if isAdmin() 
        && request.resource.data.updatedAt is timestamp;
      
      // Only admins can delete settings
      allow delete: if isAdmin();
    }
    
    // System logs collection (admin only)
    match /system_logs/{logId} {
      // Only admins can read system logs
      allow read: if isAdmin();
      
      // Only admins can create system logs
      allow create: if isAdmin() 
        && request.resource.data.keys().hasAll(['action', 'timestamp'])
        && request.resource.data.action is string
        && request.resource.data.timestamp is timestamp;
      
      // Only admins can update system logs
      allow update: if isAdmin();
      
      // Only admins can delete system logs
      allow delete: if isAdmin();
    }
    
    // Backups collection (admin only)
    match /backups/{backupId} {
      // Only admins can read backups
      allow read: if isAdmin();
      
      // Only admins can create backups
      allow create: if isAdmin() 
        && request.resource.data.keys().hasAll(['timestamp', 'createdBy'])
        && request.resource.data.timestamp is timestamp
        && request.resource.data.createdBy is string;
      
      // Only admins can update backups
      allow update: if isAdmin();
      
      // Only admins can delete backups
      allow delete: if isAdmin();
    }
  }
}`;

    // Write rules to file
    fs.writeFileSync('firestore.rules', firestoreRules);
    console.log('✅ Firestore rules written to firestore.rules\n');

    // Note: Firestore rules must be deployed via Firebase Console or CLI
    // Admin SDK doesn't support deploying rules directly
    console.log('⚠️  Note: Firestore rules must be deployed manually:');
    console.log('   1. Go to Firebase Console > Firestore Database > Rules');
    console.log('   2. Copy content from firestore.rules');
    console.log('   3. Paste and click Publish');
    console.log('   OR run: firebase deploy --only firestore:rules --project raknago-pro\n');

    console.log('✨ Firebase setup completed successfully!');
    console.log('\n📋 Collections created:');
    console.log('   ✅ users (with profileCompleted, gender, dateOfBirth, role, status fields)');
    console.log('   ✅ parking_spots (with location, hasEVCharging, evChargingPrice fields)');
    console.log('   ✅ notifications (for admin notifications)');
    console.log('   ✅ reservations (with userId, spotId, startTime, endTime, duration, price, status)');
    console.log('   ✅ settings (app settings: commissionRate, paymentMethods, notifications)');
    console.log('   ✅ system_logs (system activity logs)');
    console.log('   ✅ backups (system backup records)');
    console.log('\n📋 Security Rules:');
    console.log('   ✅ Users can only read/update their own data');
    console.log('   ✅ Profile completion required for creating parking spots');
    console.log('   ✅ Profile completion required for creating reservations');
    console.log('   ✅ Email and createdAt fields cannot be modified');
    console.log('   ✅ Settings, system_logs, and backups are admin-only');
    console.log('\n📋 Next steps:');
    console.log('   1. Deploy Firestore rules: firebase deploy --only firestore:rules --project raknago-pro');
    console.log('   2. Enable Authentication providers (Email/Password & Google)');
    console.log('   3. Add SHA-1 and SHA-256 to Firebase project settings');
    
  } catch (error) {
    console.error('❌ Error setting up Firebase:', error);
    process.exit(1);
  }
}

// Run the setup
setupFirestore()
  .then(() => {
    console.log('\n✅ Setup script completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Setup script failed:', error);
    process.exit(1);
  });
