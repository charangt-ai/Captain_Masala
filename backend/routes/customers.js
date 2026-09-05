const express = require('express');
const Customer = require('../models/Customer');
const { protect } = require('../middleware/auth');
const router = express.Router();

// @desc    Get all customers
// @route   GET /api/customers
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const customers = await Customer.find({});
    res.json(customers);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Add a customer
// @route   POST /api/customers
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const data = req.body;
    if (data.id) data._id = data.id;
    const customer = new Customer(data);
    const createdCustomer = await customer.save();
    res.status(201).json(createdCustomer);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Update a customer
// @route   PUT /api/customers/:id
// @access  Private
router.put('/:id', protect, async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (customer) {
      Object.assign(customer, req.body);
      const updatedCustomer = await customer.save();
      res.json(updatedCustomer);
    } else {
      res.status(404).json({ message: 'Customer not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// @desc    Delete a customer
// @route   DELETE /api/customers/:id
// @access  Private
router.delete('/:id', protect, async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (customer) {
      await Customer.findByIdAndDelete(req.params.id);
      res.json({ message: 'Customer removed' });
    } else {
      res.status(404).json({ message: 'Customer not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
