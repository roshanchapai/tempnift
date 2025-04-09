import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/models/drawer_state.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/services/ride_service.dart';
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

class _RiderHomeScreenState extends State<RiderHomeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<RideRequest> _rideRequests = [];
  final RideService _rideService = RideService();
  Stream<List<RideRequest>>? _requestsStream;
  StreamSubscription<List<RideRequest>>? _streamSubscription;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initRequestsStream();
  }
  
  @override
  void dispose() {
    // Cancel any active stream subscriptions
    _streamSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  
  void _initRequestsStream() {
    // Cancel any existing subscription before creating a new one
    _streamSubscription?.cancel();
    
    // Get the stream of available ride requests
    _requestsStream = _rideService.getAvailableRideRequests();
    
    // Listen to the stream and update state only if widget is still mounted
    _streamSubscription = _requestsStream?.listen((requests) {
      if (mounted) {
        setState(() {
          _rideRequests = requests;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ride requests: $error'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    });
  }
  
  // Accept a ride request
  Future<void> _acceptRideRequest(String requestId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _rideService.acceptRideRequest(
        requestId: requestId,
        riderId: widget.user.uid,
      );
      
      if (!mounted) return;
      
      setState(() {
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
              controller: _tabController,
            ),
          ),
          
          // Main content - Ride requests list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Available requests tab
                _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildRideRequestsList(),
                
                // My active rides tab (placeholder for now)
                Center(
                  child: Text(
                    'Active Rides Coming Soon',
                    style: TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                // Offer ride tab (placeholder for now)
                Center(
                  child: Text(
                    'Offer Ride Coming Soon',
                    style: TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
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
                    onPressed: _initRequestsStream,
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
            onPressed: _initRequestsStream,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
  
  // Build ride requests list
  Widget _buildRideRequestsList() {
    return StreamBuilder<List<RideRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _rideRequests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError && _rideRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: AppColors.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(
                    color: AppColors.errorColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initRequestsStream,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        // Use the cached _rideRequests list that is updated by our stream subscription
        // This avoids widget rebuild issues when the widget might be unmounting
        if (_rideRequests.isEmpty) {
          return _buildEmptyState();
        }
        
        return ListView.builder(
          itemCount: _rideRequests.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            if (index >= _rideRequests.length) return const SizedBox(); // Safety check
            
            final request = _rideRequests[index];
            final bool isAccepted = request.status == 'accepted' && request.acceptedBy == widget.user.uid;
            final minutesAgo = DateTime.now().difference(request.timestamp).inMinutes;
            
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
                                request.passengerName,
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
                            isAccepted ? 'Accepted' : 'Np. ${request.offeredPrice.toInt()}',
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
                                request.fromAddress,
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
                                request.toAddress,
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
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Map view coming soon')),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        if (!isAccepted && request.status == 'pending')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            onPressed: () {
                              if (mounted) {
                                _acceptRideRequest(request.id);
                              }
                            },
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
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contact feature coming soon'),
                                  ),
                                );
                              }
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
      },
    );
  }
} 