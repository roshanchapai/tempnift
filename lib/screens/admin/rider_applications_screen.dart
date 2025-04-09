import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';

class RiderApplicationsScreen extends StatefulWidget {
  const RiderApplicationsScreen({Key? key}) : super(key: key);

  @override
  State<RiderApplicationsScreen> createState() => _RiderApplicationsScreenState();
}

class _RiderApplicationsScreenState extends State<RiderApplicationsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  
  // Process the application (approve or reject)
  Future<void> _processApplication(String userId, String newStatus) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update status in riderApplications collection
      await FirebaseFirestore.instance
          .collection('riderApplications')
          .doc(userId)
          .update({
        'status': newStatus,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _authService.currentUser?.uid,
      });
      
      // Update user's rider status
      await _authService.updateUserRiderStatus(
        uid: userId,
        newStatus: newStatus,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: newStatus == 'approved' ? AppColors.successColor : AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing application: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Navigate to application details
  void _viewApplicationDetails(DocumentSnapshot application) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ApplicationDetailsScreen(application: application),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Applications'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('riderApplications')
            .where('status', isEqualTo: 'pending')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.errorColor),
              ),
            );
          }
          
          final applications = snapshot.data?.docs ?? [];
          
          if (applications.isEmpty) {
            return const Center(
              child: Text(
                'No pending applications',
                style: AppTextStyles.subtitleStyle,
              ),
            );
          }
          
          return ListView.builder(
            itemCount: applications.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final application = applications[index];
              final applicationData = application.data() as Map<String, dynamic>;
              
              final userId = applicationData['userId'] as String? ?? '';
              final userName = applicationData['userName'] as String? ?? 'Unknown User';
              final userPhone = applicationData['userPhone'] as String? ?? '';
              final submittedAt = applicationData['submittedAt'] as Timestamp?;
              final vehicleDetails = applicationData['vehicleDetails'] as Map<String, dynamic>? ?? {};
              
              final vehicleType = vehicleDetails['type'] as String? ?? 'Unknown';
              final vehicleNumber = vehicleDetails['number'] as String? ?? 'Unknown';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userName,
                              style: AppTextStyles.bodyBoldStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: AppColors.secondaryTextColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            userPhone,
                            style: AppTextStyles.captionStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: AppColors.secondaryTextColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$vehicleType - $vehicleNumber',
                            style: AppTextStyles.captionStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.secondaryTextColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            submittedAt != null 
                                ? 'Applied on ${submittedAt.toDate().toString().split(' ')[0]}'
                                : 'Recently applied',
                            style: AppTextStyles.captionStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: () => _viewApplicationDetails(application),
                            child: const Text('View Details'),
                          ),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: _isLoading ? null : () => _processApplication(userId, 'rejected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.errorColor,
                                ),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading ? null : () => _processApplication(userId, 'approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.successColor,
                                ),
                                child: const Text('Approve'),
                              ),
                            ],
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
      ),
    );
  }
}

class ApplicationDetailsScreen extends StatelessWidget {
  final DocumentSnapshot application;
  
  const ApplicationDetailsScreen({Key? key, required this.application}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final applicationData = application.data() as Map<String, dynamic>;
    
    final userName = applicationData['userName'] as String? ?? 'Unknown User';
    final userPhone = applicationData['userPhone'] as String? ?? '';
    final vehicleDetails = applicationData['vehicleDetails'] as Map<String, dynamic>? ?? {};
    final selfieUrl = applicationData['selfPhotoUrl'] as String?;
    final idCardUrl = applicationData['idPhotoUrl'] as String?;
    final vehicleUrl = applicationData['vehiclePhotoUrl'] as String?;
    
    final vehicleType = vehicleDetails['type'] as String? ?? 'Unknown';
    final vehicleModel = vehicleDetails['model'] as String? ?? 'Unknown';
    final vehicleNumber = vehicleDetails['number'] as String? ?? 'Unknown';
    final vehicleColor = vehicleDetails['color'] as String? ?? 'Unknown';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Application: $userName'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information
            const Text(
              'User Information',
              style: AppTextStyles.subtitleStyle,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Name'),
                      subtitle: Text(userName),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone'),
                      subtitle: Text(userPhone),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Vehicle Information
            const Text(
              'Vehicle Information',
              style: AppTextStyles.subtitleStyle,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.category),
                      title: const Text('Type'),
                      subtitle: Text(vehicleType),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.directions_car),
                      title: const Text('Model'),
                      subtitle: Text(vehicleModel),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.confirmation_number),
                      title: const Text('Number'),
                      subtitle: Text(vehicleNumber),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.color_lens),
                      title: const Text('Color'),
                      subtitle: Text(vehicleColor),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Photos
            const Text(
              'Submitted Photos',
              style: AppTextStyles.subtitleStyle,
            ),
            const SizedBox(height: 8),
            
            // Selfie
            _buildImageCard(
              context: context,
              title: 'Profile Photo',
              imageUrl: selfieUrl,
              isLoading: selfieUrl == null,
            ),
            
            const SizedBox(height: 16),
            
            // ID Card
            _buildImageCard(
              context: context,
              title: 'ID Card',
              imageUrl: idCardUrl,
              isLoading: idCardUrl == null,
            ),
            
            const SizedBox(height: 16),
            
            // Vehicle
            _buildImageCard(
              context: context,
              title: 'Vehicle Photo',
              imageUrl: vehicleUrl,
              isLoading: vehicleUrl == null,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageCard({
    required BuildContext context,
    required String title,
    required String? imageUrl,
    required bool isLoading,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: AppTextStyles.bodyBoldStyle,
            ),
          ),
          if (isLoading)
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: AppColors.errorColor,
                      size: 48,
                    ),
                  ),
                );
              },
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(
                child: Text('No image available'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: imageUrl == null
                  ? null
                  : () {
                      // Open image in full screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullScreenImage(
                            imageUrl: imageUrl!,
                            title: title,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: const Text('View Full Image'),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String title;
  
  const FullScreenImage({
    Key? key,
    required this.imageUrl,
    required this.title,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            clipBehavior: Clip.none,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.errorColor,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text('Failed to load image'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
} 