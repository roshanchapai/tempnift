import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nift_final/models/ride_offer_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';

class RideOffersScreen extends StatefulWidget {
  final UserModel passenger;

  const RideOffersScreen({
    Key? key,
    required this.passenger,
  }) : super(key: key);

  @override
  State<RideOffersScreen> createState() => _RideOffersScreenState();
}

class _RideOffersScreenState extends State<RideOffersScreen> {
  final RideService _rideService = RideService();
  StreamSubscription<List<RideOffer>>? _offersSubscription;
  List<RideOffer> _rideOffers = [];
  bool _isLoading = true;
  Map<String, UserModel?> _riderDetails = {};
  
  // For filtering
  bool _isFilterActive = false;
  double? _maxPrice;
  int _minSeats = 1;
  DateTime? _departureDate;
  
  @override
  void initState() {
    super.initState();
    _initOffersStream();
  }

  @override
  void dispose() {
    _offersSubscription?.cancel();
    super.dispose();
  }

  void _initOffersStream() {
    _offersSubscription = _rideService
        .getActiveRideOffers()
        .listen((offers) async {
      if (!mounted) return;

      setState(() {
        _rideOffers = offers;
        _isLoading = false;
      });

      // Load rider details for each offer
      for (final offer in offers) {
        if (!_riderDetails.containsKey(offer.riderId)) {
          _loadRiderDetails(offer.riderId);
        }
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading ride offers: $error'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    });
  }

  Future<void> _loadRiderDetails(String riderId) async {
    try {
      final rider = await _rideService.getUserDetails(riderId);
      if (mounted) {
        setState(() {
          _riderDetails[riderId] = rider;
        });
      }
    } catch (e) {
      debugPrint('Error loading rider details: $e');
    }
  }

  Future<void> _acceptRideOffer(RideOffer offer) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _rideService.acceptRideOffer(
        offerId: offer.id,
        passengerId: widget.passenger.uid,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride offer accepted successfully. The rider will contact you with further details.'),
          backgroundColor: AppColors.successColor,
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting ride offer: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Offers',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _maxPrice = null;
                            _minSeats = 1;
                            _departureDate = null;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Max price slider
                  Text(
                    'Maximum Price: ${_maxPrice == null ? 'Any' : '\$${_maxPrice!.toStringAsFixed(0)}'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _maxPrice ?? 100,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    onChanged: (value) {
                      setState(() {
                        _maxPrice = value;
                      });
                    },
                  ),
                  
                  // Min seats slider
                  Text(
                    'Minimum Seats: $_minSeats',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _minSeats.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    onChanged: (value) {
                      setState(() {
                        _minSeats = value.toInt();
                      });
                    },
                  ),
                  
                  // Date picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Departure Date: ${_departureDate == null ? 'Any' : DateFormat('MMM d, y').format(_departureDate!)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Select'),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _departureDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setState(() {
                              _departureDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_maxPrice != null || _minSeats > 1 || _departureDate != null) {
                          this.setState(() {
                            _isFilterActive = true;
                          });
                        } else {
                          this.setState(() {
                            _isFilterActive = false;
                          });
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  List<RideOffer> get _filteredOffers {
    if (!_isFilterActive) return _rideOffers;
    
    return _rideOffers.where((offer) {
      // Filter by max price
      if (_maxPrice != null && offer.offeredPrice > _maxPrice!) {
        return false;
      }
      
      // Filter by min seats
      if (offer.availableSeats < _minSeats) {
        return false;
      }
      
      // Filter by departure date
      if (_departureDate != null) {
        final offerDate = DateTime(
          offer.departureTime.year,
          offer.departureTime.month,
          offer.departureTime.day,
        );
        final filterDate = DateTime(
          _departureDate!.year,
          _departureDate!.month,
          _departureDate!.day,
        );
        
        if (offerDate != filterDate) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('E, MMM d');
    final timeFormat = DateFormat('h:mm a');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
            tooltip: 'Filter Offers',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rideOffers.isEmpty
              ? _buildEmptyState()
              : _buildOffersList(dateFormat, timeFormat),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: AppColors.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No ride offers available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new offers',
            style: TextStyle(
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: _initOffersStream,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList(DateFormat dateFormat, DateFormat timeFormat) {
    final filteredOffers = _filteredOffers;
    
    if (filteredOffers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off,
              size: 80,
              color: AppColors.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching offers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters',
              style: TextStyle(
                color: AppColors.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear Filters'),
              onPressed: () {
                setState(() {
                  _isFilterActive = false;
                  _maxPrice = null;
                  _minSeats = 1;
                  _departureDate = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredOffers.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final offer = filteredOffers[index];
        final riderName = _riderDetails.containsKey(offer.riderId)
            ? _riderDetails[offer.riderId]?.name ?? 'Loading...'
            : 'Loading...';
            
        final remainingSeats = offer.availableSeats - offer.acceptedPassengerIds.length;
        final isAlreadyAccepted = offer.acceptedPassengerIds.contains(widget.passenger.uid);
            
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rider info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.surfaceColor,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Driver',
                            style: TextStyle(
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
                        color: AppColors.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${offer.offeredPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 24),
                
                // Trip details
                Row(
                  children: [
                    Column(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: AppColors.primaryColor,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: AppColors.dividerColor,
                        ),
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppColors.errorColor,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From: ${offer.fromAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'To: ${offer.toAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Departure time and seats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dateFormat.format(offer.departureTime)} at ${timeFormat.format(offer.departureTime)}',
                          style: const TextStyle(
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.airline_seat_recline_normal,
                          size: 16,
                          color: AppColors.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$remainingSeats ${remainingSeats == 1 ? 'seat' : 'seats'} available',
                          style: const TextStyle(
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAlreadyAccepted || remainingSeats <= 0 || _isLoading
                        ? null
                        : () => _acceptRideOffer(offer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isAlreadyAccepted
                        ? const Text('Already Accepted')
                        : remainingSeats <= 0
                            ? const Text('No Seats Available')
                            : _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Book This Ride'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 