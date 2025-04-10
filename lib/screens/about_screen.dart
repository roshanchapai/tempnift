import 'package:flutter/material.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/nift_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // App logo and name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.primaryGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightTextColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const NiftLogo(size: 60),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nift',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.lightTextColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // App mission
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Mission',
                    style: AppTextStyles.subtitleStyle,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nift aims to revolutionize urban transportation by connecting passengers with reliable riders, creating a seamless, safe, and efficient transportation network while reducing traffic congestion and environmental impact.',
                    style: AppTextStyles.bodyStyle,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Text(
                    'Key Features',
                    style: AppTextStyles.subtitleStyle,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildFeatureItem(
                    icon: Icons.location_on_outlined,
                    title: 'Real-time Ride Tracking',
                    description: 'Track your ride in real-time from pickup to destination.',
                  ),
                  
                  _buildFeatureItem(
                    icon: Icons.security_outlined,
                    title: 'Secure Payments',
                    description: 'Multiple payment options with secure transaction processing.',
                  ),
                  
                  _buildFeatureItem(
                    icon: Icons.star_outline,
                    title: 'Rating System',
                    description: 'Rate and review your experience to help improve service quality.',
                  ),
                  
                  _buildFeatureItem(
                    icon: Icons.history,
                    title: 'Ride History',
                    description: 'Access your complete ride history for easy reference.',
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Text(
                    'Connect With Us',
                    style: AppTextStyles.subtitleStyle,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        icon: Icons.language,
                        onTap: () => _launchUrl('https://niftapp.com'),
                      ),
                      _buildSocialButton(
                        icon: Icons.facebook,
                        onTap: () => _launchUrl('https://facebook.com/niftapp'),
                      ),
                      _buildSocialButton(
                        icon: Icons.email_outlined,
                        onTap: () => _launchUrl('mailto:support@niftapp.com'),
                      ),
                      _buildSocialButton(
                        icon: Icons.phone,
                        onTap: () => _launchUrl('tel:+9771234567890'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Center(
                    child: Text(
                      '© 2023 Nift. All rights reserved.',
                      style: AppTextStyles.captionStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyBoldStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.captionStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: AppColors.primaryColor,
          size: 24,
        ),
      ),
    );
  }
} 