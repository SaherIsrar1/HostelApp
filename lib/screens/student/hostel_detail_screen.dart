import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/hostel_model.dart';
import '../../models/comment_model.dart';
import '../../services/comment_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/skeleton_loader.dart';
import 'booking_screen.dart';
import 'add_review_screen.dart';

class HostelDetailScreen extends StatefulWidget {
  final HostelModel hostel;

  const HostelDetailScreen({super.key, required this.hostel});

  @override
  State<HostelDetailScreen> createState() => _HostelDetailScreenState();
}

class _HostelDetailScreenState extends State<HostelDetailScreen> {
  int _currentImageIndex = 0;
  final MapController _mapController = MapController();
  final CommentService _commentService = CommentService();
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  double? _distanceInKm;

  // Real hostel data from Firestore
  Map<String, dynamic>? _hostelData;
  List<String> _hostelImages = [];
  bool _isLoadingData = true;

  // User's existing review
  CommentModel? _userReview;

  // Demo amenities
  final List<Map<String, dynamic>> _amenities = [
    {'icon': Icons.wifi, 'name': 'Free WiFi'},
    {'icon': Icons.local_laundry_service, 'name': 'Laundry'},
    {'icon': Icons.restaurant, 'name': 'Mess'},
    {'icon': Icons.security, 'name': '24/7 Security'},
    {'icon': Icons.local_parking, 'name': 'Parking'},
  ];

  Future<void> _openAddReviewScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          hostel: widget.hostel,
          existingReview: _userReview,
        ),
      ),
    );

    if (result == true) {
      await _checkUserReview();
      setState(() {});
    }
  }

  // ✅ FIXED: Make phone call with proper formatting
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // Clean and validate phone number
      String cleanNumber = phoneNumber.trim();

      // Remove all non-digit characters except +
      cleanNumber = cleanNumber.replaceAll(RegExp(r'[^\d+]'), '');

      debugPrint('📞 ===== CALL DEBUG =====');
      debugPrint('📞 Original: $phoneNumber');
      debugPrint('📞 Cleaned: $cleanNumber');

      if (cleanNumber.isEmpty) {
        _showErrorSnackBar('Invalid phone number');
        return;
      }

      // For Pakistani numbers starting with 0, keep as is
      // For numbers starting with 92, add +
      if (cleanNumber.startsWith('0') && cleanNumber.length == 11) {
        // Format: 03001234567 - keep as is for tel:
        cleanNumber = cleanNumber;
      } else if (cleanNumber.startsWith('92') && cleanNumber.length == 12) {
        // Format: 923001234567 - add + for international
        cleanNumber = '+$cleanNumber';
      } else if (cleanNumber.startsWith('+92')) {
        // Already correct format
        cleanNumber = cleanNumber;
      }

      final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
      debugPrint('📞 Final URI: $launchUri');

      bool canLaunch = await canLaunchUrl(launchUri);
      debugPrint('📞 Can launch: $canLaunch');

      if (canLaunch) {
        bool launched = await launchUrl(launchUri);
        debugPrint('📞 Launched: $launched');

        if (!launched) {
          _showErrorSnackBar('Could not open phone dialer');
        }
      } else {
        _showErrorSnackBar('Phone dialer not available');
      }
    } catch (e) {
      debugPrint('❌ Error making call: $e');
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  // ✅ FIXED: Open WhatsApp with pre-filled message
  Future<void> _openWhatsApp(String phoneNumber) async {
    try {
      // Clean phone number
      String cleanNumber = phoneNumber.trim();
      cleanNumber = cleanNumber.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

      debugPrint('💬 ===== WHATSAPP DEBUG =====');
      debugPrint('💬 Original: $phoneNumber');
      debugPrint('💬 Step 1 - Cleaned: $cleanNumber');

      // Convert to international format (92XXXXXXXXXX)
      if (cleanNumber.startsWith('0') && cleanNumber.length == 11) {
        // 03001234567 -> 923001234567
        cleanNumber = '92${cleanNumber.substring(1)}';
      } else if (cleanNumber.startsWith('+92')) {
        // +923001234567 -> 923001234567
        cleanNumber = cleanNumber.substring(1);
      } else if (cleanNumber.startsWith('92') && cleanNumber.length == 12) {
        // Already in correct format: 923001234567
        cleanNumber = cleanNumber;
      } else {
        _showErrorSnackBar('Invalid phone number format. Use: 03XXXXXXXXX');
        return;
      }

      debugPrint('💬 Step 2 - Formatted: $cleanNumber');

      if (cleanNumber.length != 12 || !cleanNumber.startsWith('92')) {
        _showErrorSnackBar('Invalid number format. Should be 92XXXXXXXXXX');
        return;
      }

      // Pre-filled message
      final hostelName = widget.hostel.name;
      final message = Uri.encodeComponent(
          'Hi! I am interested in *$hostelName* hostel. Can you please provide more details?'
      );

      // Try multiple WhatsApp URL formats
      final List<String> whatsappUrls = [
        'https://wa.me/$cleanNumber?text=$message',
        'https://api.whatsapp.com/send?phone=$cleanNumber&text=$message',
        'whatsapp://send?phone=$cleanNumber&text=$message',
      ];

      bool opened = false;

      for (String url in whatsappUrls) {
        debugPrint('💬 Trying URL: $url');
        final Uri uri = Uri.parse(url);

        try {
          if (await canLaunchUrl(uri)) {
            opened = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            debugPrint('💬 Success with: $url');
            if (opened) break;
          }
        } catch (e) {
          debugPrint('💬 Failed with $url: $e');
          continue;
        }
      }

      if (!opened) {
        _showErrorSnackBar('WhatsApp is not installed. Number: $cleanNumber');
      }

    } catch (e) {
      debugPrint('❌ WhatsApp Error: $e');
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  // ✅ NEW: Show contact options bottom sheet
  void _showContactOptions() {
    final contact = _hostelData?['contact'] ?? '';

    debugPrint('🔍 Contact data from Firestore: $contact');
    debugPrint('🔍 Full hostel data: $_hostelData');

    if (contact.isEmpty || contact == 'null' || contact == 'N/A') {
      _showErrorSnackBar('Contact number not available. Please contact admin.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Contact ${widget.hostel.name}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            contact,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // WhatsApp Button
                    _buildContactOptionButton(
                      icon: Icons.chat_bubble,
                      label: 'Message on WhatsApp',
                      subtitle: 'Send a quick message',
                      color: const Color(0xFF3D7853),
                      onTap: () {
                        Navigator.pop(context);
                        _openWhatsApp(contact);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Call Button
                    _buildContactOptionButton(
                      icon: Icons.phone,
                      label: 'Call Now',
                      subtitle: 'Direct phone call',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _makePhoneCall(contact);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Copy Number Button (Fallback)
                    _buildContactOptionButton(
                      icon: Icons.content_copy,
                      label: 'Copy Number',
                      subtitle: 'Copy to clipboard',
                      color: Colors.grey,
                      onTap: () {
                        Navigator.pop(context);
                        // Copy to clipboard
                        final data = ClipboardData(text: contact);
                        Clipboard.setData(data);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 12),
                                Text('Number copied: $contact'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOptionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Open location in native maps app
  Future<void> _openMaps() async {
    final lat = widget.hostel.latitude;
    final lng = widget.hostel.longitude;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.hostel.latitude,
        widget.hostel.longitude,
      );

      setState(() {
        _currentPosition = position;
        _distanceInKm = distance / 1000;
        _isLoadingLocation = false;
      });

      _centerMapOnBothLocations();
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      setState(() => _isLoadingLocation = false);
    }
  }

  void _centerMapOnBothLocations() {
    if (_currentPosition == null) return;

    final bounds = LatLngBounds(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(widget.hostel.latitude, widget.hostel.longitude),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.hostel.gender == 'Boys' ? Icons.boy : Icons.girl,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              widget.hostel.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNavigation() async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) return;
    }

    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&destination=${widget.hostel.latitude},${widget.hostel.longitude}'
        '&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadHostelData();
    _checkUserReview();
  }

  Future<void> _checkUserReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.hostel.id != null) {
      final review = await _commentService.getUserReview(
        widget.hostel.id!,
        user.uid,
      );
      if (mounted) {
        setState(() => _userReview = review);
      }
    }
  }

  Future<void> _loadHostelData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostel.id)
          .get();

      if (doc.exists) {
        setState(() {
          _hostelData = doc.data();
          _hostelImages = List<String>.from(_hostelData?['images'] ?? []);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading hostel data: $e');
      setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Loading...'),
        ),
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton
              SkeletonBox(
                width: double.infinity,
                height: 300,
                borderRadius: 0,
              ),
              const SizedBox(height: 20),
              // Title skeleton
              SkeletonBox(width: 200, height: 24),
              const SizedBox(height: 12),
              SkeletonBox(width: 140, height: 14),
              const SizedBox(height: 20),
              // Price card skeleton
              SkeletonBox(width: double.infinity, height: 70, borderRadius: 15),
              const SizedBox(height: 24),
              SkeletonBox(width: 180, height: 20),
              const SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 80, borderRadius: 12),
              const SizedBox(height: 24),
              // Amenities skeleton
              SkeletonBox(width: 160, height: 20),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(5, (i) => SkeletonBox(width: 100, height: 38, borderRadius: 12)),
              ),
              const SizedBox(height: 24),
              // Map skeleton
              SkeletonBox(width: 220, height: 20),
              const SizedBox(height: 12),
              SkeletonBox(width: double.infinity, height: 250, borderRadius: 15),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image Carousel
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  _hostelImages.isNotEmpty
                      ? PageView.builder(
                    itemCount: _hostelImages.length,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        _hostelImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppColors.grey.withOpacity(0.1),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                      : _buildPlaceholderImage(),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  ),
                  if (_hostelImages.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _hostelImages.length,
                              (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            backgroundColor: AppColors.primary,
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hostel Name & Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.hostel.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              widget.hostel.rating.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location & Gender
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        widget.hostel.city,
                        style: TextStyle(color: AppColors.grey, fontSize: 15),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        widget.hostel.gender == "Boys" ? Icons.boy : Icons.girl,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.hostel.gender} Hostel",
                        style: TextStyle(color: AppColors.grey, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Price Card
                  Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Monthly Rent",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Rs ${widget.hostel.price}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Additional Info
                  if (_hostelData != null) ...[
                    if (_hostelData!['address'] != null &&
                        _hostelData!['address'].toString().isNotEmpty) ...[
                      const Text(
                        "Address",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _hostelData!['address'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_hostelData!['description'] != null &&
                        _hostelData!['description'].toString().isNotEmpty) ...[
                      const Text(
                        "About Hostel",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey.withOpacity(0.2)),
                        ),
                        child: Text(
                          _hostelData!['description'],
                          style: TextStyle(
                            color: AppColors.textDark.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_hostelData!['facilities'] != null &&
                        _hostelData!['facilities'].toString().isNotEmpty) ...[
                      const Text(
                        "Facilities",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey.withOpacity(0.2)),
                        ),
                        child: Text(
                          _hostelData!['facilities'],
                          style: TextStyle(
                            color: AppColors.textDark.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Amenities Section
                  const Text(
                    "Amenities & Facilities",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(amenity['icon'], color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              amenity['name'],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Map Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Location & Navigation",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (_distanceInKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.directions_walk,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_distanceInKm!.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      height: 250,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(
                                widget.hostel.latitude,
                                widget.hostel.longitude,
                              ),
                              initialZoom: 13.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'com.example.hostel_app',
                                maxZoom: 20,
                              ),
                              if (_currentPosition != null)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: [
                                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                        LatLng(widget.hostel.latitude, widget.hostel.longitude),
                                      ],
                                      color: AppColors.primary,
                                      strokeWidth: 3.0,
                                      pattern: const StrokePattern.dotted(),
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      widget.hostel.latitude,
                                      widget.hostel.longitude,
                                    ),
                                    width: 100,
                                    height: 100,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            'Hostel',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.home,
                                          color: AppColors.accent,
                                          size: 40,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_currentPosition != null)
                                    Marker(
                                      point: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      width: 80,
                                      height: 80,
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              'You',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.my_location,
                                            color: Colors.green,
                                            size: 35,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: FloatingActionButton.small(
                              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                              backgroundColor: Colors.white,
                              child: _isLoadingLocation
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                                  : Icon(Icons.my_location, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.directions),
                    label: const Text("Start Navigation"),
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

                  // Reviews Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Reviews & Ratings",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openAddReviewScreen,
                        icon: Icon(
                          _userReview == null ? Icons.add : Icons.edit,
                          size: 18,
                        ),
                        label: Text(_userReview == null ? 'Add Review' : 'Edit Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<List<CommentModel>>(
                    stream: _commentService.streamHostelComments(widget.hostel.id ?? ''),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review, size: 50, color: AppColors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'No reviews yet',
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to review this hostel!',
                                style: TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final reviews = snapshot.data!;

                      return Column(
                        children: [
                          ...reviews.take(3).map((review) => _buildReviewCard(review)),
                          if (reviews.length > 3)
                            TextButton(
                              onPressed: () {
                                _showAllReviews(reviews);
                              },
                              child: Text(
                                'View all ${reviews.length} reviews',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ✅ IMPROVED: Bottom Navigation Bar with Contact Options
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Contact Button (Opens bottom sheet)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _showContactOptions,
                  icon: const Icon(Icons.phone),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.all(12),
                  ),
                  tooltip: 'Contact Hostel',
                ),
              ),
              const SizedBox(width: 12),

              // Book Now Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(hostel: widget.hostel),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Book Now",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(CommentModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(review.createdAt),
                        style: TextStyle(color: AppColors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              RatingStars(rating: review.rating),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: TextStyle(
              color: AppColors.textDark.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllReviews(List<CommentModel> reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Reviews',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${reviews.length} reviews',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  return _buildReviewCard(reviews[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}