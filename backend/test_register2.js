const mongoose = require('mongoose');
const User = require('./models/User'); // Adjust path if needed

mongoose.connect('mongodb+srv://charan:Charan%40007@cluster0.kl7xj4d.mongodb.net/captain_masala?retryWrites=true&w=majority&appName=Cluster0')
  .then(async () => {
    try {
      const user = await User.create({
        name: 'Kumar Test',
        phoneNumber: '9998887776',
        email: 'kumar.test' + Date.now() + '@example.com',
        username: 'kumar_test_' + Date.now(),
        password: 'Password123',
        role: 'seller'
      });
      console.log('User created:', user);
    } catch (e) {
      console.log('Error during register:', e);
    }
    process.exit(0);
  })
  .catch(e => {
    console.log('Connection Error:', e.message);
    process.exit(1);
  });
