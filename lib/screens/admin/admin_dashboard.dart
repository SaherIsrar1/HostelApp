import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/hostel_service.dart';
import '../../utils/app_colors.dart';
import '../auth/login_screen.dart';
import 'add_hostel_screen.dart';
import 'edit_hostel_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingService _bookingService = BookingService();
  final HostelService _hostelService = HostelService();

  int _totalHostels = 0;
  int _pendingBookings = 0;
  int _confirmedBookings = 0;
  int _totalRevenue = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardStats();
  }

  // ✅ FIXED: Better stats loading logic
  Future<void> _loadDashboardStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get admin's hostels count
      final hostelsSnapshot = await FirebaseFirestore.instance
          .collection('hostels')
          .where('adminId', isEqualTo: user.uid)
          .get();

      final totalHostels = hostelsSnapshot.docs.length;

      // Get hostel names for this admin
      final hostelNames = hostelsSnapshot.docs
          .map((doc) => (doc.data()['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      debugPrint('📊 Admin has ${hostelNames.length} hostels: $hostelNames');

      // Get all bookings for admin's hostels
      int pending = 0;
      int confirmed = 0;
      double revenue = 0;

      if (hostelNames.isNotEmpty) {
        final bookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('hostelName', whereIn: hostelNames)
            .get();

        debugPrint('📋 Found ${bookingsSnapshot.docs.length} bookings');

        for (var doc in bookingsSnapshot.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          final price = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;

          debugPrint('Booking: ${data['hostelName']} - Status: $status - Price: $price');

          if (status == 'Pending') pending++;
          if (status == 'Confirmed') {
            confirmed++;
            revenue += price;
          }
        }
      }

      setState(() {
        _totalHostels = totalHostels;
        _pendingBookings = pending;
        _confirmedBookings = confirmed;
        _totalRevenue = revenue.toInt();
        _isLoadingStats = false;
      });

      debugPrint('✅ Stats loaded: Hostels=$totalHostels, Pending=$pending, Confirmed=$confirmed, Revenue=$revenue');
    } catch (e) {
      debugPrint('❌ Error loading stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          'Admin Dashboard 🏢',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardStats,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.book_online), text: 'Bookings'),
            Tab(icon: Icon(Icons.home_work), text: 'Hostels'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildBookingsTab(),
          _buildHostelsTab(),
        ],
      ),
    );
  }

  // ============ OVERVIEW TAB ============
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
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
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: AppColors.primary, size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (_isLoadingStats)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  'Total Hostels',
                  _totalHostels.toString(),
                  Icons.home_work,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Pending Bookings',
                  _pendingBookings.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Confirmed',
                  _confirmedBookings.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Total Revenue',
                  _totalRevenue > 999 ? 'Rs ${_totalRevenue ~/ 1000}K' : 'Rs $_totalRevenue',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              'Add New Hostel',
              'Register a new hostel property',
              Icons.add_business,
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddHostelScreen()),
                ).then((_) => _loadDashboardStats());
              },
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              'View All Bookings',
              'Manage booking requests',
              Icons.list_alt,
                  () {
                _tabController.animateTo(1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
          ],
        ),
      ),
    );
  }

  // ============ BOOKINGS TAB ============
  Widget _buildBookingsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login'));
    }

    return StreamBuilder<QuerySnapshot>(
      // ✅ FIXED: First get admin's hostels
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .where('adminId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, hostelSnapshot) {
        if (hostelSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (hostelSnapshot.hasError) {
          return Center(child: Text('Error: ${hostelSnapshot.error}'));
        }

        if (!hostelSnapshot.hasData || hostelSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work, size: 80, color: AppColors.grey),
                const SizedBox(height: 16),
                Text(
                  'No hostels found',
                  style: TextStyle(color: AppColors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a hostel first to see bookings',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        // ✅ Get hostel names for THIS admin only
        final adminHostelNames = hostelSnapshot.data!.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String?)
            .where((name) => name != null && name.isNotEmpty)
            .cast<String>()
            .toList();

        debugPrint('🔒 Admin ${user.uid} hostels: $adminHostelNames');

        if (adminHostelNames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_online, size: 80, color: AppColors.grey),
                const SizedBox(height: 16),
                Text(
                  'No hostel names found',
                  style: TextStyle(color: AppColors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        // ✅ Now get ONLY bookings for THIS admin's hostels
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('hostelName', whereIn: adminHostelNames)
              .snapshots(),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (bookingSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading bookings',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${bookingSnapshot.error}',
                      style: TextStyle(color: AppColors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (!bookingSnapshot.hasData || bookingSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_online, size: 80, color: AppColors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No bookings yet',
                      style: TextStyle(color: AppColors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bookings for your hostels will appear here',
                      style: TextStyle(color: AppColors.grey, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final bookings = bookingSnapshot.data!.docs
                .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                return BookingModel.fromMap(data);
              } catch (e) {
                debugPrint('Error parsing booking: $e');
                return null;
              }
            })
                .where((booking) => booking != null)
                .cast<BookingModel>()
                .toList();

            // ✅ Sort bookings by date (newest first)
            bookings.sort((a, b) {
              // First, sort by status priority: Pending > Confirmed > Others
              const statusPriority = {
                'Pending': 1,
                'Confirmed': 2,
                'Rejected': 3,
                'Cancelled': 4,
              };

              final priorityA = statusPriority[a.status] ?? 99;
              final priorityB = statusPriority[b.status] ?? 99;

              if (priorityA != priorityB) {
                return priorityA.compareTo(priorityB);
              }

              // If same status, sort by check-in date (newest first)
              return b.checkInDate.compareTo(a.checkInDate);
            });

            debugPrint('🔒 Showing ${bookings.length} bookings for admin ${user.uid}');

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                return _buildBookingCard(bookings[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    Color statusColor;
    IconData statusIcon;

    switch (booking.status) {
      case 'Pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        break;
      case 'Confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.hostelName,
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            booking.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBookingDetail(Icons.phone, booking.studentPhone),
                const SizedBox(height: 6),
                _buildBookingDetail(Icons.calendar_today,
                    'Check-in: ${booking.checkInDate.day}/${booking.checkInDate.month}/${booking.checkInDate.year}'),
                const SizedBox(height: 6),
                _buildBookingDetail(
                    Icons.access_time, '${booking.duration} month(s)'),
                const SizedBox(height: 6),
                _buildBookingDetail(Icons.bed, booking.roomType),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grey,
                      ),
                    ),
                    Text(
                      'Rs ${booking.totalPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (booking.status == 'Pending')
            Container(
              decoration: BoxDecoration(
                color: AppColors.grey.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateBookingStatus(booking.id, 'Rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateBookingStatus(booking.id, 'Confirmed'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.grey),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: AppColors.textDark),
        ),
      ],
    );
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      await _bookingService.updateBookingStatus(bookingId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${status.toLowerCase()} successfully'),
            backgroundColor: status == 'Confirmed' ? Colors.green : Colors.red,
          ),
        );
      }
      _loadDashboardStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteHostel(String hostelId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hostel'),
        content: const Text('Are you sure you want to delete this hostel? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _hostelService.deleteHostel(hostelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadDashboardStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============ HOSTELS TAB ============
  Widget _buildHostelsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .where('adminId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work, size: 80, color: AppColors.grey),
                const SizedBox(height: 16),
                Text(
                  'No hostels yet',
                  style: TextStyle(color: AppColors.grey, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddHostelScreen()),
                    ).then((_) => _loadDashboardStats());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Your First Hostel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        final hostels = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Add Hostel Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddHostelScreen()),
                ).then((_) => _loadDashboardStats());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New Hostel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Hostels List with complete data
            ...hostels.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildHostelCardWithData(data, doc.id);
            }),
          ],
        );
      },
    );
  }

  // ✅ NEW: Updated method to pass complete data to Edit screen
  Widget _buildHostelCardWithData(Map<String, dynamic> data, String hostelId) {
    final name = data['name'] ?? 'No Name';
    final city = data['city'] ?? '';
    final gender = data['gender'] ?? '';
    final price = data['price'] ?? 0;
    final rating = (data['rating'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  gender == 'Boys' ? Icons.boy : (gender == 'Girls' ? Icons.girl : Icons.people),
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppColors.grey),
                        const SizedBox(width: 4),
                        Text(city, style: TextStyle(color: AppColors.grey)),
                        const SizedBox(width: 12),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(rating.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                'Rs $price',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // ✅ Navigate to Edit screen with complete data
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditHostelScreen(
                          hostelId: hostelId,
                          hostelData: data, // Pass complete hostel data
                        ),
                      ),
                    ).then((updated) {
                      if (updated == true) {
                        _loadDashboardStats(); // Refresh data after edit
                      }
                    });
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteHostel(hostelId),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}