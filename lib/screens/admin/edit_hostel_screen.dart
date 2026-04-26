import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';

class EditHostelScreen extends StatefulWidget {
  final String hostelId;
  final Map<String, dynamic> hostelData;

  const EditHostelScreen({
    super.key,
    required this.hostelId,
    required this.hostelData,
  });

  @override
  State<EditHostelScreen> createState() => _EditHostelScreenState();
}

class _EditHostelScreenState extends State<EditHostelScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _facilitiesController;
  late TextEditingController _contactController;

  late String _selectedCity;
  late String _selectedGender;
  bool _isLoading = false;

  // Location
  late double _latitude;
  late double _longitude;
  String _locationStatus = '';

  // Images
  List<String> _existingImages = [];
  List<File> _newImages = [];
  final ImagePicker _picker = ImagePicker();

  // ImgBB API
  static const String imgbbApiKey = 'f6254b797f0b4de1945ff52767dce3a8';

  final List<String> _cities = [
    'Sahiwal',
    'Lahore',
    'Karachi',
    'Islamabad',
    'Faisalabad',
    'Multan',
    'Rawalpindi',
  ];

  final List<String> _genderOptions = ['Boys', 'Girls', 'Co-ed'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.hostelData['name'] ?? '');
    _addressController = TextEditingController(text: widget.hostelData['address'] ?? '');
    _priceController = TextEditingController(text: widget.hostelData['price']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.hostelData['description'] ?? '');
    _facilitiesController = TextEditingController(text: widget.hostelData['facilities'] ?? '');
    _contactController = TextEditingController(text: widget.hostelData['contact'] ?? '');

    _selectedCity = widget.hostelData['city'] ?? 'Sahiwal';
    _selectedGender = widget.hostelData['gender'] ?? 'Boys';

    _latitude = (widget.hostelData['latitude'] ?? 0.0).toDouble();
    _longitude = (widget.hostelData['longitude'] ?? 0.0).toDouble();
    _locationStatus = '✓ Location set ($_latitude, $_longitude)';

    _existingImages = List<String>.from(widget.hostelData['images'] ?? []);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatus = '✓ Location updated (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Location captured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 60,
        maxWidth: 1200,
      );

      if (images.isNotEmpty) {
        setState(() {
          _newImages = images.map((xFile) => File(xFile.path)).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} new image(s) selected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadNewImages() async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < _newImages.length; i++) {
      try {
        debugPrint('📤 Uploading new image ${i + 1}/${_newImages.length}...');

        final bytes = await _newImages[i].readAsBytes();
        final base64Image = base64Encode(bytes);

        final url = Uri.parse('https://api.imgbb.com/1/upload');

        final response = await http.post(
          url,
          body: {
            'key': imgbbApiKey,
            'image': base64Image,
            'name': 'hostel_${DateTime.now().millisecondsSinceEpoch}_$i',
          },
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Upload timeout');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['success'] == true) {
            final imageUrl = data['data']['url'] as String;
            uploadedUrls.add(imageUrl);
            debugPrint('✅ Image ${i + 1} uploaded');
          }
        }
      } catch (e) {
        debugPrint('❌ Error uploading image ${i + 1}: $e');
        throw Exception('Failed to upload image ${i + 1}');
      }
    }

    return uploadedUrls;
  }

  String? _validateField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required';
    }
    if (value.trim().length < 10) {
      return 'Enter a valid contact number';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }
    final price = int.tryParse(value.trim());
    if (price == null || price <= 0) {
      return 'Enter a valid price';
    }
    return null;
  }

  Future<void> _updateHostel() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_existingImages.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please add at least one image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Show uploading dialog if there are new images
      if (_newImages.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Uploading new images...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Upload new images
        final newUrls = await _uploadNewImages();
        _existingImages.addAll(newUrls);

        if (!mounted) return;
        Navigator.pop(context); // Close uploading dialog
      }

      // Update hostel in Firestore
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .update({
        'name': _nameController.text.trim(),
        'city': _selectedCity,
        'gender': _selectedGender,
        'price': int.parse(_priceController.text.trim()),
        'latitude': _latitude,
        'longitude': _longitude,
        'images': _existingImages,
        'address': _addressController.text.trim(),
        'contact': _contactController.text.trim(),
        'description': _descriptionController.text.trim(),
        'facilities': _facilitiesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Success dialog
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
              const Text('Hostel Updated!', textAlign: TextAlign.center),
            ],
          ),
          content: const Text(
            'Your hostel has been successfully updated.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Go back with success flag
              },
              child: Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('🔴 Error: $e');

      if (!mounted) return;

      // Close uploading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _facilitiesController.dispose();
    _contactController.dispose();
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
          'Edit Hostel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Images Section
                _buildSectionTitle('Hostel Images *'),
                const SizedBox(height: 12),

                // Existing Images
                if (_existingImages.isNotEmpty) ...[
                  const Text(
                    'Current Images:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(_existingImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => _removeExistingImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // New Images
                if (_newImages.isNotEmpty) ...[
                  const Text(
                    'New Images:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _newImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_newImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => _removeNewImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add More Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  validator: (value) => _validateField(value, 'Hostel name'),
                  decoration: InputDecoration(
                    hintText: 'Hostel Name *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // City Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey.withOpacity(0.3)),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'City',
                    ),
                    items: _cities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCity = value!);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Gender Selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey.withOpacity(0.3)),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Hostel Type',
                    ),
                    items: _genderOptions.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedGender = value!);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  validator: (value) => _validateField(value, 'Address'),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Complete Address *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _contactController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Contact Number *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Pricing'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  validator: _validatePrice,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Monthly Rent (Rs) *',
                    prefixText: 'Rs ',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Location *'),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _locationStatus,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Update Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Additional Details'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  validator: (value) => _validateField(value, 'Description'),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your hostel *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _facilitiesController,
                  validator: (value) => _validateField(value, 'Facilities'),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'List facilities *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Update Button
                CustomButton(
                  text: _isLoading ? 'Updating...' : 'Update Hostel',
                  onPressed: _isLoading ? null : _updateHostel,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
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
}