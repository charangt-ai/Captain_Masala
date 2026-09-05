const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./firebase-service-account.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function check() {
  const collections = await db.listCollections();
  console.log("Collections:", collections.map(c => c.id));
  
  const products = await db.collection('products').get();
  console.log("Products Count:", products.size);
  
  const cat = await db.collection('categories').get();
  console.log("Categories Count:", cat.size);
}
check().then(() => process.exit(0)).catch(console.error);
