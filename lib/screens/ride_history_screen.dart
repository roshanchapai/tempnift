import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RideHistoryScreen extends StatefulWidget {
  final UserModel user;
  
  const RideHistoryScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedRides = [];
  List<Map<String, dynamic>> _cancelledRides = [];
  String? _errorMessage;
  bool _hasMoreRides = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 15;
  bool _isLoadingMore = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRideHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRideHistory({bool loadMore = false}) async {
    if (loadMore && !_hasMoreRides) return;
    
    setState(() {
      if (!loadMore) {
        _isLoading = true;
        _errorMessage = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String uid = widget.user.uid;
      final bool isRider = widget.user.userRole == UserRole.rider;
      
      // Field to query based on user role
      final String userField = isRider ? 'acceptedBy' : 'passengerId';
      
      // Get completed rides
      Query query = firestore.collection('rideRequests')
          .where(userField, isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);
      
      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final QuerySnapshot completedSnapshot = await query.get();
      
      // Get cancelled rides in a separate query
      Query cancelledQuery = firestore.collection('rideRequests')
          .where(userField, isEqualTo: uid)
          .where('status', isEqualTo: 'cancelled')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);
      
      if (loadMore && _lastDocument != null) {
        cancelledQuery = cancelledQuery.startAfterDocument(_lastDocument!);
      }
      
      final QuerySnapshot cancelledSnapshot = await cancelledQuery.get();
      
      // Process the results
      final List<Map<String, dynamic>> completedRides = completedSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
      
      final List<Map<String, dynamic>> cancelledRides = cancelledSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // If user is a passenger, fetch missing rider details for completed rides
      if (!isRider) {
        await _fetchMissingRiderDetails(completedRides);
        // Also fetch missing rider details for cancelled rides that were previously accepted
        await _fetchMissingRiderDetails(cancelledRides);
        
        // Filter out cancelled rides that were never accepted by a rider
        // Only show cancelled rides where a driver had accepted the ride
        if (!isRider) {
          cancelledRides.removeWhere((ride) => ride['acceptedBy'] == null);
        }
      }
      
      setState(() {
        if (loadMore) {
          _completedRides.addAll(completedRides);
          _cancelledRides.addAll(cancelledRides);
        } else {
          _completedRides = completedRides;
          _cancelledRides = cancelledRides;
        }
        
        _hasMoreRides = completedSnapshot.docs.length == _pageSize || 
                        cancelledSnapshot.docs.length == _pageSize;
        
        if (completedSnapshot.docs.isNotEmpty) {
          _lastDocument = completedSnapshot.docs.last;
        } else if (cancelledSnapshot.docs.isNotEmpty) {
          _lastDocument = cancelledSnapshot.docs.last;
        }
        
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading ride history: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshRideHistory() async {
    setState(() {
      _lastDocument = null;
      _hasMoreRides = true;
    });
    await _loadRideHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.lightTextColor,
          labelColor: AppColors.lightTextColor,
          unselectedLabelColor: AppColors.lightTextColor.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: AppTextStyles.bodyStyle.copyWith(
                          color: AppColors.errorColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshRideHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Completed Rides Tab
                    _buildRidesList(_completedRides, 'completed'),
                    
                    // Cancelled Rides Tab
                    _buildRidesList(_cancelledRides, 'cancelled'),
                  ],
                ),
    );
  }

  Widget _buildRidesList(List<Map<String, dynamic>> rides, String type) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'completed' ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 64,
              color: AppColors.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type.toLowerCase()} rides found',
              style: AppTextStyles.bodyStyle.copyWith(
                color: AppColors.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _refreshRideHistory,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRideHistory,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!_isLoadingMore && 
              _hasMoreRides &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadRideHistory(loadMore: true);
            return true;
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length + (_hasMoreRides ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == rides.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final ride = rides[index];
            return _buildRideCard(ride, widget.user.userRole);
          },
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, UserRole userRole) {
    // Format date and time
    final timestamp = (ride['timestamp'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy').format(timestamp);
    final formattedTime = DateFormat('h:mm a').format(timestamp);
    
    // Determine card color based on status
    final cardColor = ride['status'] == 'completed' 
        ? AppColors.successColor.withOpacity(0.05)
        : AppColors.warningColor.withOpacity(0.05);
    
    // Set appropriate info based on user role
    final String otherPersonName = userRole == UserRole.rider
        ? ride['passengerName'] ?? 'Passenger'
        : ride['riderName'] ?? 'Rider';
    
    final String otherPersonPhone = userRole == UserRole.rider
        ? ride['passengerPhone'] ?? 'N/A'
        : ride['riderPhone'] ?? 'N/A';
    
    final String otherPersonId = userRole == UserRole.rider
        ? ride['passengerId'] ?? ''
        : ride['acceptedBy'] ?? '';
    
    final IconData roleIcon = userRole == UserRole.rider
        ? Icons.person
        : Icons.directions_car;

    // Get price information
    final double offeredPrice = (ride['offeredPrice'] ?? 0).toDouble();
    final double? finalPrice = ride['finalPrice']?.toDouble();
    final double? estimatedDistance = ride['estimatedDistance']?.toDouble();
    
    // Determine if this is a ride that needs extra attention for display
    final bool isCompletedWithRider = ride['status'] == 'completed' && 
                                     userRole == UserRole.passenger && 
                                     ride['acceptedBy'] != null &&
                                     (ride['riderName'] == null || ride['riderPhone'] == null);
    
    // Determine if we should show driver phone info
    final bool showDriverContact = userRole == UserRole.passenger && 
                                  ride['status'] == 'completed' &&
                                  ride['riderPhone'] != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ride['status'] == 'completed'
              ? AppColors.successColor.withOpacity(0.2)
              : AppColors.warningColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to ride details screen
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and status row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$formattedDate · $formattedTime',
                    style: AppTextStyles.captionStyle,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride['status'] == 'completed'
                          ? AppColors.successColor.withOpacity(0.1)
                          : AppColors.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride['status'] == 'completed' ? 'Completed' : 'Cancelled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ride['status'] == 'completed'
                            ? AppColors.successColor
                            : AppColors.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Locations
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.pickupMarkerColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride['fromAddress'] ?? 'Unknown pickup',
                      style: AppTextStyles.bodyStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.flag,
                    color: AppColors.destinationMarkerColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride['toAddress'] ?? 'Unknown destination',
                      style: AppTextStyles.bodyStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Person info and price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Person info
                  Row(
                    children: [
                      Icon(
                        roleIcon,
                        size: 16,
                        color: AppColors.secondaryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        otherPersonName,
                        style: AppTextStyles.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  // Price info
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        size: 16,
                        color: AppColors.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        // Show final price if available, otherwise offered price
                        'Rs. ${(finalPrice ?? offeredPrice).toInt()}',
                        style: AppTextStyles.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Show driver phone if available
              if (showDriverContact) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.phone,
                      size: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      otherPersonPhone,
                      style: AppTextStyles.captionStyle,
                    ),
                  ],
                ),
              ],
              
              // Show distance info if available
              if (estimatedDistance != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(
                      Icons.route,
                      size: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${estimatedDistance.toStringAsFixed(1)} km',
                      style: AppTextStyles.captionStyle,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to calculate time ago
  String _calculateTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to fetch missing rider details
  Future<void> _fetchMissingRiderDetails(List<Map<String, dynamic>> rides) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final List<Future<void>> fetchTasks = [];
    
    for (final ride in rides) {
      // Only process rides that have an acceptedBy but missing rider details
      if (ride['acceptedBy'] != null && 
          (ride['riderName'] == null || ride['riderPhone'] == null)) {
        
        final String riderId = ride['acceptedBy'];
        fetchTasks.add(
          firestore.collection('users').doc(riderId).get().then((userDoc) {
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              // Update the ride with rider info
              ride['riderName'] = userData['name'] ?? 'Unknown Rider';
              ride['riderPhone'] = userData['phoneNumber'] ?? 'No Phone';
              
              // Also update the original document to fix it for future queries
              firestore.collection('rideRequests').doc(ride['id']).update({
                'riderName': ride['riderName'],
                'riderPhone': ride['riderPhone'],
              });
            }
          }).catchError((e) {
            debugPrint('Error fetching rider details: $e');
          })
        );
      }
    }
    
    // Wait for all fetch tasks to complete
    if (fetchTasks.isNotEmpty) {
      await Future.wait(fetchTasks);
    }
  }
} 