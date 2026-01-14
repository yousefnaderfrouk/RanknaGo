const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./raknago-pro-firebase-adminsdk-fbsvc-01ae84e6ba.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'raknago-pro'
});

const db = admin.firestore();

async function listAllUsers() {
  try {
    console.log('📋 Listing all users in Firestore...\n');
    
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users found in Firestore collection!\n');
      console.log('💡 Make sure users have signed up and their documents were created.\n');
      return;
    }

    console.log(`✅ Found ${usersSnapshot.size} user(s):\n`);
    
    usersSnapshot.forEach((doc, index) => {
      const userData = doc.data();
      console.log(`${index + 1}. ${userData.email || 'N/A'}`);
      console.log(`   Name: ${userData.name || 'N/A'}`);
      console.log(`   Role: ${userData.role || 'user'}`);
      console.log(`   Status: ${userData.status || 'active'}`);
      console.log(`   User ID: ${doc.id}`);
      console.log('');
    });

    // Check if the specific email exists
    const targetEmail = 'keroyousf18@gmail.com';
    const found = usersSnapshot.docs.find(doc => {
      const email = (doc.data().email || '').toLowerCase().trim();
      return email === targetEmail.toLowerCase().trim();
    });

    if (found) {
      console.log(`\n✅ Found target user: ${targetEmail}`);
      console.log(`   User ID: ${found.id}`);
      console.log(`   Current Role: ${found.data().role || 'user'}\n`);
      
      // Ask if user wants to make them admin
      const readline = require('readline');
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });

      rl.question('Make this user admin? (yes/no): ', async (answer) => {
        if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
          await db.collection('users').doc(found.id).update({
            role: 'admin',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log('\n✅ User is now admin!');
          console.log('   Logout and login again to see admin dashboard.\n');
        } else {
          console.log('\n❌ Operation cancelled.\n');
        }
        rl.close();
        process.exit(0);
      });
    } else {
      console.log(`\n⚠️  Target email "${targetEmail}" not found in the list above.`);
      console.log('   Please check the email spelling or make sure the user has signed up.\n');
      process.exit(0);
    }
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

listAllUsers();


































