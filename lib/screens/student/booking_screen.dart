import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/hostel_model.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';

class BookingScreen extends StatefulWidget {
  final HostelModel hostel;

  const BookingScreen({super.key, required this.hostel});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingService _bookingService = BookingService();
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();

  // Booking Details
  DateTime? _checkInDate;
  String _roomType = 'Single';
  String _mealPlan = 'No Meal';
  int _duration = 1; // months
  bool _isLoading = false;

  final List<String> _roomTypes = ['Single', 'Double', 'Triple', 'Quad'];
  final List<String> _mealPlans = ['No Meal', 'Breakfast Only', 'Half Board', 'Full Board'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _nameController.text = user.displayName ?? '';
      });
    }
  }

  Future<void> _selectCheckInDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _checkInDate = picked);
    }
  }

  double _calculateTotalPrice() {
    double basePrice = widget.hostel.price.toDouble();
    double roomMultiplier = 1.0;
    double mealPrice = 0.0;

    // Room type pricing
    switch (_roomType) {
      case 'Single':
        roomMultiplier = 1.0;
        break;
      case 'Double':
        roomMultiplier = 0.75;
        break;
      case 'Triple':
        roomMultiplier = 0.6;
        break;
      case 'Quad':
        roomMultiplier = 0.5;
        break;
    }

    // Meal plan pricing
    switch (_mealPlan) {
      case 'Breakfast Only':
        mealPrice = 1500;
        break;
      case 'Half Board':
        mealPrice = 3000;
        break;
      case 'Full Board':
        mealPrice = 4500;
        break;
    }

    return ((basePrice * roomMultiplier) + mealPrice) * _duration;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_checkInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final booking = BookingModel(
        id: '',
        userId: user.uid,
        hostelId: widget.hostel.name, // In real app, use proper hostel ID
        hostelName: widget.hostel.name,
        studentName: _nameController.text.trim(),
        studentPhone: _phoneController.text.trim(),
        studentCnic: _cnicController.text.trim(),
        studentAddress: _addressController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim(),
        checkInDate: _checkInDate!,
        duration: _duration,
        roomType: _roomType,
        mealPlan: _mealPlan,
        totalPrice: _calculateTotalPrice(),
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      await _bookingService.createBooking(booking);

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
              ),
              const SizedBox(height: 16),
              const Text('Booking Submitted!', textAlign: TextAlign.center),
            ],
          ),
          content: const Text(
            'Your booking request has been sent to the hostel admin. You will be notified once it is confirmed.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Book Your Room',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hostel Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home, color: Colors.white, size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.hostel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              widget.hostel.city,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              widget.hostel.rating.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Booking Form
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Personal Information'),
                    const SizedBox(height: 12),
                    _buildTextField(_nameController, 'Full Name', Icons.person),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneController, 'Phone Number', Icons.phone,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(_cnicController, 'CNIC (13 digits)', Icons.credit_card,
                        keyboardType: TextInputType.number, maxLength: 13),
                    const SizedBox(height: 16),
                    _buildTextField(_addressController, 'Permanent Address', Icons.home_outlined,
                        maxLines: 2),
                    const SizedBox(height: 16),
                    _buildTextField(_emergencyContactController, 'Emergency Contact', Icons.emergency,
                        keyboardType: TextInputType.phone),

                    const SizedBox(height: 24),
                    _buildSectionTitle('Booking Details'),
                    const SizedBox(height: 12),

                    // Check-in Date
                    InkWell(
                      onTap: _selectCheckInDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Check-in Date',
                                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _checkInDate == null
                                        ? 'Select Date'
                                        : DateFormat('dd MMM yyyy').format(_checkInDate!),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duration Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(
                                'Duration: $_duration month${_duration > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _duration > 1
                                    ? () => setState(() => _duration--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.primary,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _duration.toDouble(),
                                  min: 1,
                                  max: 12,
                                  divisions: 11,
                                  activeColor: AppColors.primary,
                                  onChanged: (value) {
                                    setState(() => _duration = value.toInt());
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: _duration < 12
                                    ? () => setState(() => _duration++)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Room Type
                    _buildDropdown(
                      'Room Type',
                      _roomType,
                      _roomTypes,
                      Icons.bed,
                          (value) => setState(() => _roomType = value!),
                    ),
                    const SizedBox(height: 16),

                    // Meal Plan
                    _buildDropdown(
                      'Meal Plan',
                      _mealPlan,
                      _mealPlans,
                      Icons.restaurant,
                          (value) => setState(() => _mealPlan = value!),
                    ),

                    const SizedBox(height: 24),

                    // Price Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent.withOpacity(0.1), AppColors.primary.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Base Price:',
                                style: TextStyle(fontSize: 15),
                              ),
                              Text(
                                'Rs ${widget.hostel.price}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Room Type:', style: TextStyle(fontSize: 15)),
                              Text(_roomType, style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Duration:', style: TextStyle(fontSize: 15)),
                              Text('$_duration month${_duration > 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Rs ${_calculateTotalPrice().toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    CustomButton(
                      text: _isLoading ? 'Submitting...' : 'Submit Booking Request',
                      onPressed: _isLoading ? null : _submitBooking,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType? keyboardType,
        int maxLines = 1,
        int? maxLength,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }
        if (label.contains('Phone') || label.contains('Contact')) {
          if (value.length < 11) return 'Enter valid phone number';
        }
        if (label.contains('CNIC') && value.length != 13) {
          return 'CNIC must be 13 digits';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(
      String label,
      String value,
      List<String> items,
      IconData icon,
      Function(String?) onChanged,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}