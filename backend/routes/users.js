const express = require('express');
const User = require('../models/User');
const { protect, admin, superAdmin } = require('../middleware/auth');
const router = express.Router();

// @desc    Get user profile
// @route   GET /api/users/me
// @access  Private
router.get('/me', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (user) {
      res.json(user);
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update user profile
// @route   PUT /api/users/me
// @access  Private
router.put('/me', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    if (user) {
      // Check username uniqueness
      if (req.body.username && req.body.username !== user.username) {
        const existingUser = await User.findOne({ username: req.body.username });
        if (existingUser) {
          return res.status(400).json({ message: 'Username is already taken' });
        }
      }

      user.name = req.body.name || user.name;
      user.phoneNumber = req.body.phoneNumber || user.phoneNumber;
      user.username = req.body.username || user.username;

      const updatedUser = await user.save();

      res.json({
        id: updatedUser._id,
        name: updatedUser.name,
        email: updatedUser.email,
        phoneNumber: updatedUser.phoneNumber,
        username: updatedUser.username,
        role: updatedUser.role,
        requestedRole: updatedUser.requestedRole
      });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Request role change
// @route   POST /api/users/request-role
// @access  Private
router.post('/request-role', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (user) {
      user.requestedRole = req.body.role;
      await user.save();
      res.json({ message: 'Role requested successfully' });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Get active users
// @route   GET /api/users/active
// @access  Private/Admin
router.get('/active', protect, admin, async (req, res) => {
  try {
    const users = await User.find({ role: { $in: ['seller', 'delivery'] } }).select('-password');
    res.json(users);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Get pending users
// @route   GET /api/users/pending
// @access  Private/Admin
router.get('/pending', protect, admin, async (req, res) => {
  try {
    const users = await User.find({
      $or: [
        { role: 'pending' },
        { requestedRole: { $ne: null } }
      ]
    }).select('-password');
    res.json(users);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Approve user
// @route   PUT /api/users/:id/approve
// @access  Private/Admin
router.put('/:id/approve', protect, admin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (user) {
      user.role = user.requestedRole || 'seller';
      user.requestedRole = undefined; // clear it
      await user.save();
      res.json({ message: 'User approved' });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Reject user
// @route   PUT /api/users/:id/reject
// @access  Private/Admin
router.put('/:id/reject', protect, admin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (user) {
      if (user.role === 'pending') {
        await User.findByIdAndDelete(req.params.id);
        res.json({ message: 'Pending user deleted' });
      } else {
        user.requestedRole = undefined; // clear it
        await user.save();
        res.json({ message: 'Role request rejected' });
      }
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Change user role directly
// @route   PUT /api/users/:id/role
// @access  Private/Admin
router.put('/:id/role', protect, admin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (user) {
      user.role = req.body.role;
      await user.save();
      res.json({ message: 'Role updated successfully' });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Delete user account completely
// @route   DELETE /api/users/:id
// @access  Private/Admin
router.delete('/:id', protect, admin, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (user) {
      await User.findByIdAndDelete(req.params.id);
      res.json({ message: 'User completely deleted' });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
