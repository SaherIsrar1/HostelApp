import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../services/hostel_service.dart';
import '../../models/hostel_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import 'location_picker_screen.dart';

class AddHostelScreen extends StatefulWidget {
  const AddHostelScreen({super.key});

  @override
  State<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends State<AddHostelScreen> {
  final HostelService _hostelService = HostelService();
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _facilitiesController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _selectedCity = 'Sahiwal';
  String _selectedGender = 'Boys';
  bool _isLoading = false;
  bool _isGettingLocation = false;

  // Location variables
  double? _latitude;
  double? _longitude;
  String _locationMethod = 'Not Set';

  List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final ImagePicker _picker = ImagePicker();

  // ✅ ImgBB API Key (Free - No Credit Card Required!)
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

  // ✅ Get Current Location (Auto Detect)
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please enable location in settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable in device settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationMethod = 'Auto-detected (GPS)';
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
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  // ✅ Pick location from map
  Future<void> _pickLocationFromMap() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _latitude ?? 30.6624,
          initialLng: _longitude ?? 73.1019,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _locationMethod = 'Picked from Map';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Location selected from map!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 60,
        maxWidth: 1200,
      );

      if (images.isNotEmpty && images.length <= 5) {
        setState(() {
          _selectedImages = images.map((xFile) => File(xFile.path)).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} image(s) selected'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (images.length > 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can select maximum 5 images')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error selecting images')),
      );
    }
  }

  // ✅ Upload to ImgBB (Free Image Hosting)
  Future<void> _uploadImagesToImgBB() async {
    _uploadedImageUrls.clear();

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📤 Uploading image ${i + 1}/${_selectedImages.length} to ImgBB');

        // Read image as bytes and convert to base64
        final bytes = await _selectedImages[i].readAsBytes();
        final base64Image = base64Encode(bytes);

        debugPrint('📊 Size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

        // ImgBB upload URL
        final url = Uri.parse('https://api.imgbb.com/1/upload');

        // Make HTTP POST request
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
            _uploadedImageUrls.add(imageUrl);

            debugPrint('✅ SUCCESS! Image ${i + 1} uploaded');
            debugPrint('🔗 $imageUrl');
          } else {
            throw Exception('ImgBB API error: ${data['error']['message']}');
          }
        } else {
          debugPrint('❌ Upload failed: ${response.statusCode}');
          debugPrint('Response: ${response.body}');
          throw Exception('Upload failed with status ${response.statusCode}');
        }

      } on SocketException catch (e) {
        debugPrint('❌ NETWORK ERROR: $e');
        throw Exception('No internet connection. Please check your WiFi or mobile data.');
      } catch (e) {
        debugPrint('❌ UPLOAD ERROR: $e');

        String errorMsg = 'Failed to upload image ${i + 1}';
        if (e.toString().contains('timeout')) {
          errorMsg = 'Upload timeout. Check your internet connection.';
        } else if (e.toString().contains('Invalid API key')) {
          errorMsg = 'Invalid ImgBB API key. Please check your configuration.';
        }

        throw Exception(errorMsg);
      }
    }

    debugPrint('✅ All ${_uploadedImageUrls.length} images uploaded to ImgBB!');
  }

  // Form Validation
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
      return 'Enter a valid contact number (min 10 digits)';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }
    final price = int.tryParse(value.trim());
    if (price == null || price <= 0) {
      return 'Enter a valid price (greater than 0)';
    }
    return null;
  }

  Future<void> _submitHostel() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill all required fields correctly'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check images
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please add at least one image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check location
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please set location using "Auto Detect" or "Pick on Map"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      debugPrint('🚀 Starting hostel submission...');

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text(
                        'Uploading images...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This may take a minute',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Upload images using ImgBB (Free)
      debugPrint('📤 Starting image upload to ImgBB...');
      await _uploadImagesToImgBB();
      debugPrint('✅ All images uploaded!');

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      final hostel = HostelModel(
        name: _nameController.text.trim(),
        city: _selectedCity,
        gender: _selectedGender,
        rating: 0.0,
        price: int.parse(_priceController.text.trim()),
        latitude: _latitude!,
        longitude: _longitude!,
      );

      debugPrint('💾 Saving hostel to Firestore...');
      await _hostelService.addHostelWithImages(
        hostel,
        user.uid,
        _uploadedImageUrls,
        _addressController.text.trim(),
        _contactController.text.trim(),
        _descriptionController.text.trim(),
        _facilitiesController.text.trim(),
      );
      debugPrint('✅ Hostel saved successfully!');

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
              const Text('Hostel Added!', textAlign: TextAlign.center),
            ],
          ),
          content: const Text(
            'Your hostel has been successfully registered and is now visible to students.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('OK', style: TextStyle(color: AppColors.primary, fontSize: 16)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('🔴 Error: $e');

      if (!mounted) return;

      // Close progress dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _submitHostel,
          ),
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
          'Add New Hostel',
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
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fill in all the details about your hostel to attract more students',
                          style: TextStyle(color: AppColors.textDark, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('Hostel Images *'),
                const SizedBox(height: 8),
                Text(
                  'Add 1-5 clear images of your hostel',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // Image Picker Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      if (_selectedImages.isEmpty)
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary,
                                style: BorderStyle.solid,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                    size: 50,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add images',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(_selectedImages[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _selectedImages.removeAt(index);
                                              });
                                            },
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
                            OutlinedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: Text('Change Images (${_selectedImages.length}/5)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
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
                      borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
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
                  child: DropdownButtonHideUnderline(
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
                  child: DropdownButtonHideUnderline(
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
                      borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _contactController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Contact Number (e.g., 03001234567) *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
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
                      borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Hostel Location *'),
                const SizedBox(height: 8),
                Text(
                  'Choose how to set your hostel location',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // Location Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _latitude != null
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _latitude != null ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _latitude != null ? Icons.check_circle : Icons.location_off,
                        color: _latitude != null ? Colors.green : Colors.orange,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latitude != null ? 'Location Set ✓' : 'Location Not Set',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _latitude != null ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _latitude != null
                                  ? _locationMethod
                                  : 'Choose a method below',
                              style: TextStyle(
                                color: AppColors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (_latitude != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Location Options
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isGettingLocation ? null : _getCurrentLocation,
                        icon: _isGettingLocation
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.my_location, size: 20),
                        label: Text(_isGettingLocation ? 'Getting...' : 'Auto Detect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickLocationFromMap,
                        icon: const Icon(Icons.map, size: 20),
                        label: const Text('Pick on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Additional Details'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  validator: (value) => _validateField(value, 'Description'),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your hostel (facilities, rules, etc.) *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _facilitiesController,
                  validator: (value) => _validateField(value, 'Facilities'),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'List facilities (WiFi, Laundry, AC, etc.) *',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: _isLoading ? 'Adding Hostel...' : 'Add Hostel',
                  onPressed: _isLoading ? null : _submitHostel,
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