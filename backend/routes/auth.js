const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const router = express.Router();

const generateToken = (id, role) => {
  return jwt.sign({ id, role }, process.env.JWT_SECRET, {
    expiresIn: '30d',
  });
};

// @desc    Register a new user (seller/admin)
// @route   POST /api/auth/register
// @access  Public
router.post('/register', async (req, res) => {
  const { name, phone, email, username, password, role } = req.body;

  try {
    const userExists = await User.findOne({
      $or: [{ email }, { username }]
    });

    if (userExists) {
      return res.status(400).json({ message: 'User already exists (email or username taken)' });
    }

    const assignedRole = role === 'super_admin' ? 'super_admin' : 'pending';

    const user = await User.create({
      name,
      phoneNumber: phone,
      email,
      username,
      password,
      role: assignedRole,
    });

    if (user) {
      res.status(201).json({
        id: user._id,
        name: user.name,
        email: user.email,
        username: user.username,
        role: user.role,
        token: generateToken(user._id, user.role),
      });
    } else {
      res.status(400).json({ message: 'Invalid user data' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Auth user & get token
// @route   POST /api/auth/login
// @access  Public
router.post('/login', async (req, res) => {
  const usernameOrEmail = (req.body.usernameOrEmail || '').trim();
  const password = req.body.password;
  const isUsername = !usernameOrEmail.includes('@');

  try {
    let user;
    if (usernameOrEmail.toLowerCase() === 'admin' || usernameOrEmail.toLowerCase() === 'superadmin') {
      user = await User.findOne({ email: 'admin@captainmasala.com' });
    } else {
      user = await User.findOne({
        $or: [
          { email: usernameOrEmail.toLowerCase() },
          { username: { $regex: new RegExp(`^${usernameOrEmail}$`, 'i') } },
          { name: { $regex: new RegExp(`^${usernameOrEmail}$`, 'i') } }
        ]
      });
    }

    if (user && (await user.matchPassword(password))) {
      res.json({
        id: user._id,
        name: user.name,
        email: user.email,
        username: user.username,
        role: user.role,
        token: generateToken(user._id, user.role),
      });
    } else {
      res.status(401).json({ message: 'Invalid email/username or password' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Change password
// @route   PUT /api/auth/change-password
// @access  Private
router.put('/change-password', protect, async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  try {
    const user = await User.findById(req.user.id);
    
    if (user && (await user.matchPassword(currentPassword))) {
      user.password = newPassword;
      await user.save();
      res.json({ message: 'Password updated successfully' });
    } else {
      res.status(401).json({ message: 'Invalid current password' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
