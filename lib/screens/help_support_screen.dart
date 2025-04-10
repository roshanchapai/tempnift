import 'package:flutter/material.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nift_final/models/user_model.dart';

class HelpSupportScreen extends StatefulWidget {
  final UserModel? user;
  
  const HelpSupportScreen({Key? key, this.user}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _submitSupportRequest() async {
    if (_subjectController.text.trim().isEmpty || 
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your request has been submitted. We\'ll get back to you soon.'),
          backgroundColor: AppColors.successColor,
        ),
      );

      // Clear the form
      _subjectController.clear();
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRider = widget.user?.userRole == UserRole.rider;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.lightTextColor,
          labelColor: AppColors.lightTextColor,
          unselectedLabelColor: AppColors.lightTextColor.withOpacity(0.7),
          tabs: const [
            Tab(text: 'FAQs'),
            Tab(text: 'Contact Us'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // FAQs Tab
          _buildFaqSection(isRider),
          
          // Contact Us Tab
          _buildContactSection(),
        ],
      ),
    );
  }

  Widget _buildFaqSection(bool isRider) {
    // Define FAQs based on user role
    final List<Map<String, String>> faqs = isRider
        ? _riderFaqs
        : _passengerFaqs;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Frequently Asked Questions',
          style: AppTextStyles.subtitleStyle,
        ),
        const SizedBox(height: 16),
        
        // FAQ expansion panels
        ...faqs.map((faq) => _buildFaqItem(
          question: faq['question']!,
          answer: faq['answer']!,
        )).toList(),
        
        const SizedBox(height: 24),
        
        const Text(
          'Still have questions?',
          style: AppTextStyles.bodyBoldStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _tabController.animateTo(1);
          },
          child: const Text('Contact our support team'),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Us',
            style: AppTextStyles.subtitleStyle,
          ),
          const SizedBox(height: 24),
          
          // Contact options
          Row(
            children: [
              Expanded(
                child: _buildContactOptionCard(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: 'roshanchapai@gmail.com',
                  onTap: () => _launchUrl('mailto:roshanchapai@gmail.com'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContactOptionCard(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  subtitle: '+977 9805752350',
                  onTap: () => _launchUrl('tel:+9779805752350'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Support form
          const Text(
            'Submit a Request',
            style: AppTextStyles.bodyBoldStyle,
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.subject),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              prefixIcon: Icon(Icons.message_outlined),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSupportRequest,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.lightTextColor,
                      ),
                    )
                  : const Text('Submit Request'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Support hours
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support Hours',
                  style: AppTextStyles.bodyBoldStyle,
                ),
                SizedBox(height: 8),
                Text('Sunday to Thursday: 9 AM - 6 PM'),
                Text('Friday: 10 AM - 2 PM'),
                Text('Saturday: Closed'),
                SizedBox(height: 8),
                Text(
                  'We typically respond within 24 hours on business days.',
                  style: AppTextStyles.captionStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.surfaceColor,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: AppTextStyles.bodyBoldStyle.copyWith(
            fontSize: 15,
          ),
        ),
        iconColor: AppColors.primaryColor,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: AppTextStyles.bodyStyle.copyWith(
              color: AppColors.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.surfaceColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppColors.primaryColor,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTextStyles.bodyBoldStyle,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.captionStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Predefined FAQs for passengers
  final List<Map<String, String>> _passengerFaqs = [
    {
      'question': 'How do I book a ride?',
      'answer': 'To book a ride, open the app and enter your destination. The app will show you available riders nearby. You can select a rider based on their rating and estimated arrival time.',
    },
    {
      'question': 'How do I pay for my ride?',
      'answer': 'We currently support cash payments only. Pay your rider directly at the end of your journey. We are working on adding digital payment options soon.',
    },
    {
      'question': 'Can I schedule a ride in advance?',
      'answer': 'Yes, you can schedule a ride up to 7 days in advance. Use the "Schedule" option after entering your destination to select your preferred date and time.',
    },
    {
      'question': 'How do I rate my rider?',
      'answer': 'After completing a ride, you will be prompted to rate your experience. You can also add comments and tips for the rider.',
    },
    {
      'question': 'What if my rider cancels?',
      'answer': 'If your rider cancels, you will be automatically matched with another available rider nearby. You will receive a notification with the new rider details.',
    },
    {
      'question': 'Is there a cancellation fee?',
      'answer': 'There is no cancellation fee if you cancel within 2 minutes of booking. After that, a small fee may apply depending on your rider proximity to your pickup location.',
    },
  ];
  
  // Predefined FAQs for riders
  final List<Map<String, String>> _riderFaqs = [
    {
      'question': 'How do I start accepting ride requests?',
      'answer': 'Once your account is approved as a rider, you can go online by toggling the "Available" switch on the home screen. You will then start receiving ride requests.',
    },
    {
      'question': 'How do I get paid?',
      'answer': 'Currently, all payments are made in cash directly by passengers. We are working on adding digital payment options that will deposit funds to your registered bank account.',
    },
    {
      'question': 'What happens if I need to cancel a ride?',
      'answer': 'You can cancel a ride if necessary, but frequent cancellations may affect your rating. To maintain a good standing, only accept rides you are confident you can complete.',
    },
    {
      'question': 'How are fares calculated?',
      'answer': 'Fares are calculated based on distance, estimated time, and current demand. The app will show you the fare before you accept a ride request.',
    },
    {
      'question': 'Can I see where the passenger is going before accepting?',
      'answer': 'Yes, you will see the pickup and drop-off locations, as well as the estimated fare before accepting any ride request.',
    },
    {
      'question': 'What if I have an emergency during a ride?',
      'answer': 'In case of an emergency, use the SOS button in the app. This will alert our support team and provide options to contact emergency services.',
    },
  ];
} 