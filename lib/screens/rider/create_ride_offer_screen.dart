import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nift_final/models/place_models.dart';
import 'package:nift_final/models/ride_offer_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:nift_final/services/places_service.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/search_results_overlay.dart';

class CreateRideOfferScreen extends StatefulWidget {
  final UserModel rider;
  
  const CreateRideOfferScreen({
    Key? key,
    required this.rider,
  }) : super(key: key);

  @override
  State<CreateRideOfferScreen> createState() => _CreateRideOfferScreenState();
}

class _CreateRideOfferScreenState extends State<CreateRideOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rideService = RideService();
  
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _priceController = TextEditingController();
  final _seatsController = TextEditingController(text: '1');
  
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  
  bool _isPickupSearching = false;
  bool _isDestinationSearching = false;
  bool _isLoading = false;
  List<PlacePrediction> _searchResults = [];
  
  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _seatsController.dispose();
    super.dispose();
  }
  
  void _searchLocation(String query, bool isPickup) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    try {
      final results = await PlacesService.getPlacePredictions(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    }
  }
  
  void _selectLocation(PlacePrediction prediction, bool isPickup) async {
    setState(() {
      if (isPickup) {
        _isPickupSearching = false;
      } else {
        _isDestinationSearching = false;
      }
      _searchResults = [];
    });
    
    try {
      final placeDetails = await PlacesService.getPlaceDetails(prediction.placeId);
      if (placeDetails != null && mounted) {
        setState(() {
          if (isPickup) {
            _pickupController.text = placeDetails.formattedAddress;
            _pickupLocation = placeDetails.latLng;
          } else {
            _destinationController.text = placeDetails.formattedAddress;
            _destinationLocation = placeDetails.latLng;
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
  }
  
  Future<void> _selectDepartureTime() async {
    final initialTime = TimeOfDay.fromDateTime(_departureTime);
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null) {
      // Create a new DateTime with the selected time
      setState(() {
        _departureTime = DateTime(
          _departureTime.year,
          _departureTime.month,
          _departureTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }
  
  Future<void> _selectDepartureDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _departureTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null) {
      // Preserve the time but update the date
      setState(() {
        _departureTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _departureTime.hour,
          _departureTime.minute,
        );
      });
    }
  }
  
  Future<void> _getCurrentLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() {
        _pickupLocation = location;
      });
      
      final address = await LocationService.getAddressFromLatLng(location);
      if (address != null && mounted) {
        setState(() {
          _pickupController.text = address;
        });
      }
    }
  }
  
  void _createRideOffer() async {
    if (_formKey.currentState!.validate()) {
      if (_pickupLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a pickup location'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      
      if (_destinationLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a destination'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        final price = double.parse(_priceController.text);
        final seats = int.parse(_seatsController.text);
        
        await _rideService.createRideOffer(
          rider: widget.rider,
          fromAddress: _pickupController.text,
          toAddress: _destinationController.text,
          fromLocation: _pickupLocation!,
          toLocation: _destinationLocation!,
          offeredPrice: price,
          availableSeats: seats,
          departureTime: _departureTime,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride offer created successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
          
          // Go back to previous screen
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating ride offer: $e'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('E, MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Ride Offer'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pickup location
                Text(
                  'Pickup Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pickupController,
                  decoration: InputDecoration(
                    hintText: 'Enter pickup location',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: _getCurrentLocation,
                      tooltip: 'Use current location',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onTap: () {
                    setState(() {
                      _isPickupSearching = true;
                      _isDestinationSearching = false;
                    });
                  },
                  onChanged: (value) => _searchLocation(value, true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pickup location';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Destination location
                Text(
                  'Destination',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    hintText: 'Enter destination',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  onTap: () {
                    setState(() {
                      _isDestinationSearching = true;
                      _isPickupSearching = false;
                    });
                  },
                  onChanged: (value) => _searchLocation(value, false),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter destination';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Departure date & time
                Text(
                  'Departure Date & Time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(dateFormat.format(_departureTime)),
                        onPressed: _selectDepartureDate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(timeFormat.format(_departureTime)),
                        onPressed: _selectDepartureTime,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Available seats
                Text(
                  'Available Seats',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _seatsController,
                  decoration: const InputDecoration(
                    hintText: 'Number of available seats',
                    prefixIcon: Icon(Icons.airline_seat_recline_normal),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter number of seats';
                    }
                    final seats = int.tryParse(value);
                    if (seats == null || seats < 1 || seats > 8) {
                      return 'Please enter a valid number between 1 and 8';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Price
                Text(
                  'Price per Seat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    hintText: 'Price in USD',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Create button
                ElevatedButton(
                  onPressed: _isLoading ? null : _createRideOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Ride Offer'),
                ),
              ],
            ),
          ),
          if (_isPickupSearching || _isDestinationSearching)
            Positioned(
              top: _isPickupSearching ? 120 : 220,
              left: 16,
              right: 16,
              child: SearchResultsOverlay(
                isPickupSearching: _isPickupSearching,
                searchResults: _searchResults,
                onLocationSelected: (result, isPickup) {
                  _selectLocation(result, isPickup);
                },
              ),
            ),
        ],
      ),
    );
  }
} 