const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin SDK
const serviceAccount = require('./raknago-pro-firebase-adminsdk-fbsvc-01ae84e6ba.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'raknago-pro'
});

const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function makeAdmin() {
  try {
    console.log('🔐 Make User Admin\n');
    
    rl.question('Enter user email: ', async (email) => {
      try {
        // Find user by email
        const usersSnapshot = await db.collection('users')
          .where('email', '==', email)
          .get();

        if (usersSnapshot.empty) {
          console.log('❌ User not found!');
          rl.close();
          return;
        }

        const userDoc = usersSnapshot.docs[0];
        const userId = userDoc.id;
        const userData = userDoc.data();

        console.log(`\n📋 User Info:`);
        console.log(`   Name: ${userData.name}`);
        console.log(`   Email: ${userData.email}`);
        console.log(`   Current Role: ${userData.role || 'user'}`);
        console.log(`   User ID: ${userId}\n`);

        rl.question('Make this user admin? (yes/no): ', async (answer) => {
          if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
            await db.collection('users').doc(userId).update({
              role: 'admin',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log('\n✅ User is now admin!');
            console.log('   The user needs to logout and login again to see admin dashboard.\n');
          } else {
            console.log('\n❌ Operation cancelled.\n');
          }
          rl.close();
        });
      } catch (error) {
        console.error('❌ Error:', error);
        rl.close();
      }
    });
  } catch (error) {
    console.error('❌ Error:', error);
    rl.close();
  }
}

makeAdmin();


































