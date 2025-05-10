import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/utils/price_calculator.dart';

class RideRequestScreen extends StatefulWidget {
  final UserModel passenger;
  final String pickupAddress;
  final String destinationAddress;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  
  const RideRequestScreen({
    Key? key,
    required this.passenger,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLocation,
    required this.destinationLocation,
  }) : super(key: key);

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final RideService _rideService = RideService();
  final TextEditingController _priceController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Price calculation
  double _suggestedPrice = 0;
  double _estimatedDistance = 0;
  Map<String, dynamic> _priceFactors = {};
  bool _isCalculatingPrice = true;
  bool _isPeakHours = false;
  bool _isHighDemand = false;
  
  @override
  void initState() {
    super.initState();
    _calculateSuggestedPrice();
  }
  
  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }
  
  // Calculate a suggested price using the advanced calculator
  Future<void> _calculateSuggestedPrice() async {
    setState(() {
      _isCalculatingPrice = true;
    });
    
    try {
      // Get price and factors from the advanced calculator
      final suggestedPrice = await PriceCalculator.calculateSuggestedPrice(
        widget.pickupLocation, 
        widget.destinationLocation,
      );
      
      // Check for peak hours
      _isPeakHours = _isPeakTimeNow();
      
      // Check for high demand (just for UI display)
      _isHighDemand = DateTime.now().millisecondsSinceEpoch % 10 > 7;
      
      // Calculate estimated distance (more accurate than Euclidean)
      _estimatedDistance = PriceCalculator.calculateHaversineDistance(
        widget.pickupLocation, 
        widget.destinationLocation
      );
      
      // Store price factors
      _priceFactors = {
        'basePrice': PriceCalculator.basePrice,
        'distanceKm': _estimatedDistance.toStringAsFixed(1),
        'perKmRate': PriceCalculator.perKmRate,
        'isPeakHours': _isPeakHours,
        'isHighDemand': _isHighDemand,
      };
      
      setState(() {
        _suggestedPrice = suggestedPrice;
        _priceController.text = _suggestedPrice.toStringAsFixed(0);
        _isCalculatingPrice = false;
      });
    } catch (e) {
      // Fallback to simple calculation if advanced fails
      final lat1 = widget.pickupLocation.latitude;
      final lon1 = widget.pickupLocation.longitude;
      final lat2 = widget.destinationLocation.latitude;
      final lon2 = widget.destinationLocation.longitude;
      
      // Simple Euclidean distance
      final distance = ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1)).abs();
      
      // Convert to km (very rough approximation)
      final distanceKm = distance * 111;
      _estimatedDistance = distanceKm;
      
      // Base price plus distance factor
      _suggestedPrice = 100 + (distanceKm * 50);
      
      // Round to nearest 10
      _suggestedPrice = ((_suggestedPrice / 10).round() * 10).toDouble();
      
      // Set initial price
      setState(() {
        _priceController.text = _suggestedPrice.toStringAsFixed(0);
        _isCalculatingPrice = false;
      });
    }
  }
  
  bool _isPeakTimeNow() {
    final now = DateTime.now();
    final isWeekday = now.weekday >= DateTime.monday && now.weekday <= DateTime.friday;
    final isPeakMorning = now.hour >= 7 && now.hour < 9;
    final isPeakEvening = now.hour >= 17 && now.hour < 19;
    return isWeekday && (isPeakMorning || isPeakEvening);
  }
  
  // Submit the ride request
  Future<void> _submitRequest() async {
    // Validate price
    if (_priceController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a price';
      });
      return;
    }
    
    final double price;
    try {
      price = double.parse(_priceController.text);
      if (price <= 0) {
        setState(() {
          _errorMessage = 'Please enter a valid price';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Please enter a valid price';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      if (!mounted) return;
      
      final request = await _rideService.createRideRequest(
        passenger: widget.passenger,
        fromAddress: widget.pickupAddress,
        toAddress: widget.destinationAddress,
        fromLocation: widget.pickupLocation,
        toLocation: widget.destinationLocation,
        offeredPrice: price,
      );
      
      if (!mounted) return;
      
      Navigator.of(context).pop(request);
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error creating request: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Ride'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location details
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ride Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.pickupMarkerColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'From: ${widget.pickupAddress}',
                            maxLines: 2,
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
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'To: ${widget.destinationAddress}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.route,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Distance: ${_estimatedDistance.toStringAsFixed(1)} km',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    
                    // Price factors
                    if (!_isCalculatingPrice) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Price Factors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (_isPeakHours)
                            _buildFactorChip('Peak Hours', Colors.amber),
                          if (_isHighDemand)
                            _buildFactorChip('High Demand', Colors.orange),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Price input section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Your Price',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Prominent Calculated Price Display
                    _isCalculatingPrice
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Suggested Price',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rs. ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      _suggestedPrice.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Price breakdown
                                const SizedBox(height: 12),
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Base price:'),
                                        Text('Rs. ${PriceCalculator.basePrice.toInt()}'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Distance:'),
                                        Text('${_estimatedDistance.toStringAsFixed(1)} km'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Per km rate:'),
                                        Text('Rs. ${PriceCalculator.perKmRate.toInt()}'),
                                      ],
                                    ),
                                    if (_isPeakHours) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: const [
                                          Text('Peak hours:'),
                                          Text('+25%', style: TextStyle(color: AppColors.accentColor)),
                                        ],
                                      ),
                                    ],
                                    if (_isHighDemand) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: const [
                                          Text('High demand:'),
                                          Text('+30%', style: TextStyle(color: AppColors.accentColor)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                    
                    const Text(
                      'You can adjust the suggested price or set your own.',
                      style: TextStyle(
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Price input field
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price (NRs.)',
                        hintText: 'Enter amount',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Price suggestion chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPriceChip(_suggestedPrice),
                        _buildPriceChip(_suggestedPrice - 20),
                        _buildPriceChip(_suggestedPrice + 20),
                        _buildPriceChip(_suggestedPrice + 50),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: AppColors.errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            
            const Spacer(),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPriceChip(double price) {
    // Ensure price is not negative
    final displayPrice = price > 0 ? price : 50;
    
    return ActionChip(
      label: Text('Rs. ${displayPrice.toInt()}'),
      backgroundColor: AppColors.surfaceColor,
      onPressed: () {
        setState(() {
          _priceController.text = displayPrice.toInt().toString();
        });
      },
    );
  }
  
  Widget _buildFactorChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color.withOpacity(0.5), width: 1),
    );
  }
} 