const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./firebase-service-account.json');

initializeApp({
  credential: cert(serviceAccount)
});
const db = getFirestore();

async function inspectFirebase() {
  try {
    // List all collections
    const collections = await db.listCollections();
    console.log('=== ALL FIREBASE COLLECTIONS ===\n');
    
    for (const col of collections) {
      const snapshot = await col.get();
      console.log(`\n--- Collection: "${col.id}" (${snapshot.size} documents) ---`);
      
      // Show first 2 documents as samples
      let count = 0;
      snapshot.forEach(doc => {
        if (count < 2) {
          console.log(`\n  Document ID: ${doc.id}`);
          const data = doc.data();
          // Print each field
          for (const [key, value] of Object.entries(data)) {
            if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
              if (value.toDate) {
                console.log(`    ${key}: ${value.toDate().toISOString()} (Timestamp)`);
              } else {
                console.log(`    ${key}: ${JSON.stringify(value).substring(0, 200)}`);
              }
            } else if (Array.isArray(value)) {
              console.log(`    ${key}: [Array with ${value.length} items]`);
              if (value.length > 0) {
                console.log(`      Sample item: ${JSON.stringify(value[0]).substring(0, 300)}`);
              }
            } else if (typeof value === 'string' && value.length > 100) {
              console.log(`    ${key}: "${value.substring(0, 100)}..." (${value.length} chars)`);
            } else {
              console.log(`    ${key}: ${JSON.stringify(value)}`);
            }
          }
          count++;
        }
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

inspectFirebase();
