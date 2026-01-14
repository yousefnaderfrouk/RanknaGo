const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./raknago-pro-firebase-adminsdk-fbsvc-01ae84e6ba.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'raknago-pro'
});

const db = admin.firestore();

async function makeSpecificAdmin() {
  try {
    const email = 'keroyousf18@gmail.com';
    
    console.log('🔐 Making user admin...\n');
    console.log(`📧 Searching for: ${email}\n`);
    
    // First, try to find user by exact email
    let usersSnapshot = await db.collection('users')
      .where('email', '==', email)
      .get();

    // If not found, get all users and search manually (case-insensitive)
    if (usersSnapshot.empty) {
      console.log('⚠️  Exact match not found. Searching all users...\n');
      const allUsersSnapshot = await db.collection('users').get();
      
      const matchingUsers = [];
      allUsersSnapshot.forEach(doc => {
        const userData = doc.data();
        const userEmail = (userData.email || '').toLowerCase().trim();
        if (userEmail === email.toLowerCase().trim()) {
          matchingUsers.push({ id: doc.id, data: userData });
        }
      });

      if (matchingUsers.length > 0) {
        console.log(`✅ Found ${matchingUsers.length} matching user(s):\n`);
        matchingUsers.forEach((user, index) => {
          console.log(`   ${index + 1}. Name: ${user.data.name || 'N/A'}`);
          console.log(`      Email: ${user.data.email}`);
          console.log(`      Role: ${user.data.role || 'user'}`);
          console.log(`      ID: ${user.id}\n`);
        });

        const userDoc = matchingUsers[0];
        const userId = userDoc.id;
        const userData = userDoc.data;

        console.log(`📋 Updating user:`);
        console.log(`   Name: ${userData.name || 'N/A'}`);
        console.log(`   Email: ${userData.email}`);
        console.log(`   Current Role: ${userData.role || 'user'}`);
        console.log(`   User ID: ${userId}\n`);

        // Update user to admin
        await db.collection('users').doc(userId).update({
          role: 'admin',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('✅ User is now admin!');
        console.log('\n📝 Next steps:');
        console.log('   1. Logout from the app');
        console.log('   2. Login again');
        console.log('   3. You will see Admin Dashboard automatically\n');
        
        process.exit(0);
        return;
      }
    }

    if (usersSnapshot.empty) {
      console.log('❌ User not found in Firestore!');
      console.log('\n📋 Available users in database:');
      
      const allUsersSnapshot = await db.collection('users').get();
      if (allUsersSnapshot.empty) {
        console.log('   No users found in database.\n');
      } else {
        console.log(`   Total users: ${allUsersSnapshot.size}\n`);
        allUsersSnapshot.forEach((doc, index) => {
          const userData = doc.data();
          console.log(`   ${index + 1}. ${userData.email || 'N/A'} (${userData.name || 'N/A'})`);
        });
        console.log('\n💡 Tip: Make sure the user has completed signup and profile.');
        console.log('   The user document is created when they sign up.\n');
      }
      process.exit(1);
      return;
    }

    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();

    console.log(`📋 User Info:`);
    console.log(`   Name: ${userData.name || 'N/A'}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Current Role: ${userData.role || 'user'}`);
    console.log(`   User ID: ${userId}\n`);

    // Update user to admin
    await db.collection('users').doc(userId).update({
      role: 'admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ User is now admin!');
    console.log('\n📝 Next steps:');
    console.log('   1. Logout from the app');
    console.log('   2. Login again');
    console.log('   3. You will see Admin Dashboard automatically\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

makeSpecificAdmin();

