const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');

mongoose.connect('mongodb+srv://charan:Charan%40007@cluster0.kl7xj4d.mongodb.net/captain_masala?retryWrites=true&w=majority&appName=Cluster0')
  .then(async () => {
    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash('Captain@123', salt);
    console.log('New hash:', hash);

    const result = await mongoose.connection.db.collection('users').updateMany(
      {},
      { $set: { password: hash } }
    );
    console.log('Updated', result.modifiedCount, 'users');

    // Verify
    const verify = await bcrypt.compare('Captain@123', hash);
    console.log('Verify hash works:', verify);

    // Also fix the admin lookup email
    const adminUser = await mongoose.connection.db.collection('users').findOne({ username: 'admin' });
    if (adminUser) {
      console.log('Admin user found. Email:', adminUser.email);
    }

    process.exit(0);
  })
  .catch(e => {
    console.log('Error:', e.message);
    process.exit(1);
  });
