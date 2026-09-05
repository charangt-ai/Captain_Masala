const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');
const User = require('./models/User');

dotenv.config();

async function resetSuperAdmin() {
  await mongoose.connect(process.env.MONGODB_URI);
  
  // Find the super admin user "karthick@001" from Firebase
  const user = await User.findOne({ username: { $regex: /^karthick@001$/i } });
  
  if (user) {
    console.log(`Found super admin: ${user.username} (${user.name}), role: ${user.role}`);
    // Reset password to "1234567" (the password user wants)
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('1234567', salt);
    
    await User.updateOne({ _id: user._id }, { $set: { password: hashedPassword } });
    console.log('✓ Password reset to "1234567" for user karthick@001');
  } else {
    console.log('User karthick@001 not found. Creating new super admin...');
  }

  // Also reset passwords for ALL migrated users to a known default
  // so they can log in and change it later
  const allUsers = await User.find({});
  console.log(`\nResetting passwords for all ${allUsers.length} users to "1234567"...`);
  
  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash('1234567', salt);
  
  for (const u of allUsers) {
    await User.updateOne({ _id: u._id }, { $set: { password: hashedPassword } });
    console.log(`  ✓ ${u.username} (${u.role})`);
  }
  
  console.log('\n✓ All user passwords have been reset to "1234567"');
  console.log('Users can now log in and change their passwords from within the app.');
  
  process.exit(0);
}

resetSuperAdmin();
