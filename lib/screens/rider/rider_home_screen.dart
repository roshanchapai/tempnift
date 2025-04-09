import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/models/drawer_state.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/app_drawer.dart';

class RiderHomeScreen extends StatefulWidget {
  final UserModel user;
  final DrawerState drawerState;
  
  const RiderHomeScreen({
    Key? key, 
    required this.user,
    required this.drawerState,
  }) : super(key: key);

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _rideRequests = [];
  
  @override
  void initState() {
    super.initState();
    _fetchRideRequests();
  }
  
  // Fetch ride requests that don't have a rider yet
  Future<void> _fetchRideRequests() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real implementation, we would fetch from Firestore
      // For now, adding mock data for demonstration
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      setState(() {
        _rideRequests.addAll([
          {
            'id': '1',
            'passengerId': 'user123',
            'passengerName': 'John Doe',
            'from': 'Kathmandu Durbar Square',
            'to': 'Thamel',
            'offeredPrice': 250,
            'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
            'status': 'pending',
          },
          {
            'id': '2',
            'passengerId': 'user456',
            'passengerName': 'Jane Smith',
            'from': 'Bouddhanath Stupa',
            'to': 'Pashupatinath Temple',
            'offeredPrice': 350,
            'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
            'status': 'pending',
          },
          {
            'id': '3',
            'passengerId': 'user789',
            'passengerName': 'Mike Johnson',
            'from': 'Tribhuvan Airport',
            'to': 'Hotel Yak & Yeti',
            'offeredPrice': 500,
            'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
            'status': 'pending',
          },
        ]);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ride requests: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Accept a ride request
  Future<void> _acceptRideRequest(String requestId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // In a real implementation, we would update Firestore
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      setState(() {
        // Update the local state to reflect acceptance
        final index = _rideRequests.indexWhere((req) => req['id'] == requestId);
        if (index != -1) {
          _rideRequests[index]['status'] = 'accepted';
          _rideRequests[index]['acceptedBy'] = widget.user.uid;
        }
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request accepted successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting ride request: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            widget.drawerState.scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      body: Column(
        children: [
          // Rider info banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primaryColor,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(
                    Icons.directions_car,
                    size: 30,
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${widget.user.name ?? 'Rider'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You are in RIDER mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: AppColors.successColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Tabs for different views
          Container(
            color: AppColors.surfaceColor,
            child: TabBar(
              tabs: const [
                Tab(text: 'Available Requests'),
                Tab(text: 'My Active Rides'),
                Tab(text: 'Offer Ride'),
              ],
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: AppColors.secondaryTextColor,
              indicatorColor: AppColors.primaryColor,
              controller: TabController(length: 3, vsync: AnimatedListState()),
            ),
          ),
          
          // Main content - Ride requests list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rideRequests.isEmpty
                    ? _buildEmptyState()
                    : _buildRideRequestsList(),
          ),
          
          // Action buttons at bottom
          Container(
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
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Requests'),
                    onPressed: _fetchRideRequests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Offer a Ride'),
                    onPressed: () {
                      // TODO: Navigate to ride offer screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ride offer feature coming soon'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
  
  // Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No ride requests available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pull down to refresh or check back later',
            style: TextStyle(
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchRideRequests,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
  
  // Build ride requests list
  Widget _buildRideRequestsList() {
    return ListView.builder(
      itemCount: _rideRequests.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final request = _rideRequests[index];
        final bool isAccepted = request['status'] == 'accepted';
        final timestamp = request['timestamp'] as DateTime;
        final minutesAgo = DateTime.now().difference(timestamp).inMinutes;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.surfaceColor,
                      child: const Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['passengerName'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$minutesAgo minutes ago',
                            style: const TextStyle(
                              color: AppColors.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAccepted
                            ? AppColors.successColor
                            : AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAccepted ? 'Accepted' : 'Np. ${request['offeredPrice']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // From location
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From',
                            style: TextStyle(
                              color: AppColors.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            request['from'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Dotted line
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: SizedBox(
                    height: 30,
                    child: VerticalDivider(
                      color: AppColors.secondaryTextColor.withOpacity(0.3),
                      thickness: 1,
                      width: 1,
                    ),
                  ),
                ),
                
                // To location
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: AppColors.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'To',
                            style: TextStyle(
                              color: AppColors.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            request['to'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      onPressed: () {
                        // TODO: Show on map
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Map view coming soon')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    if (!isAccepted)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                        onPressed: () => _acceptRideRequest(request['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successColor,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.phone),
                        label: const Text('Contact'),
                        onPressed: () {
                          // TODO: Implement contact functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contact feature coming soon'),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 