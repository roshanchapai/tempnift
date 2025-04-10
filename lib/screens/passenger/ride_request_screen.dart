import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';

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
  
  // Default price suggestion
  double _suggestedPrice = 0;
  
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
  
  // Calculate a suggested price based on distance
  void _calculateSuggestedPrice() {
    // Simple distance-based calculation
    // A real implementation would use a more sophisticated algorithm
    final lat1 = widget.pickupLocation.latitude;
    final lon1 = widget.pickupLocation.longitude;
    final lat2 = widget.destinationLocation.latitude;
    final lon2 = widget.destinationLocation.longitude;
    
    // Simple Euclidean distance
    final distance = ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1)).abs();
    
    // Convert to km (very rough approximation)
    final distanceKm = distance * 111;
    
    // Base price plus distance factor
    _suggestedPrice = 100 + (distanceKm * 50);
    
    // Round to nearest 10
    _suggestedPrice = ((_suggestedPrice / 10).round() * 10).toDouble();
    
    // Set initial price
    _priceController.text = _suggestedPrice.toStringAsFixed(0);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      'Your Trip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Pickup location
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
                            color: AppColors.pickupMarkerColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pickup',
                                style: TextStyle(
                                  color: AppColors.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.pickupAddress,
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
                    
                    // Destination
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
                            color: AppColors.destinationMarkerColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destination',
                                style: TextStyle(
                                  color: AppColors.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.destinationAddress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
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
                    const Text(
                      'Enter the amount you are willing to pay for this ride.',
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
                      children: [
                        _buildPriceChip(_suggestedPrice - 50),
                        _buildPriceChip(_suggestedPrice),
                        _buildPriceChip(_suggestedPrice + 50),
                        _buildPriceChip(_suggestedPrice + 100),
                      ],
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
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
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
} 