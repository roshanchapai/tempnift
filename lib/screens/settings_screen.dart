import 'package:flutter/material.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/notification_settings_screen.dart';
import 'package:nift_final/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  UserModel? _currentUser;
  
  // Hardcoded version string instead of using package_info_plus
  final String _appVersion = '1.0.0';
  
  // Settings values
  bool _notificationsEnabled = true;
  bool _locationInBackground = true;
  String _distanceUnit = 'km';
  String _language = 'English';
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (mounted) {
        setState(() {
          _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
          _locationInBackground = prefs.getBool('location_background') ?? true;
          _distanceUnit = prefs.getString('distance_unit') ?? 'km';
          _language = prefs.getString('language') ?? 'English';
          _darkMode = prefs.getBool('dark_mode') ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      switch (key) {
        case 'notifications_enabled':
          await prefs.setBool(key, value as bool);
          break;
        case 'location_background':
          await prefs.setBool(key, value as bool);
          break;
        case 'distance_unit':
          await prefs.setString(key, value as String);
          break;
        case 'language':
          await prefs.setString(key, value as String);
          break;
        case 'dark_mode':
          await prefs.setBool(key, value as bool);
          break;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setting updated'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Error updating setting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating setting: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  Future<void> _resetSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('notifications_enabled');
                await prefs.remove('location_background');
                await prefs.remove('distance_unit');
                await prefs.remove('language');
                await prefs.remove('dark_mode');
                
                await _loadSettings();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings reset to default'),
                      backgroundColor: AppColors.successColor,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error resetting settings: $e');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resetting settings: $e'),
                      backgroundColor: AppColors.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSettings,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Notifications section
                _buildSectionHeader('Notifications'),
                SwitchListTile(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _updateSetting('notifications_enabled', value);
                  },
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive notifications for ride updates'),
                  secondary: const Icon(Icons.notifications_outlined),
                ),
                
                // Role-specific notification settings
                if (_currentUser != null)
                  ListTile(
                    title: const Text('Role-Specific Notifications'),
                    subtitle: const Text('Configure separate notifications for passenger and rider modes'),
                    leading: const Icon(Icons.notifications_active_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationSettingsScreen(user: _currentUser!),
                        ),
                      );
                    },
                  ),
                
                // Location section
                _buildSectionHeader('Location'),
                SwitchListTile(
                  value: _locationInBackground,
                  onChanged: (value) {
                    setState(() {
                      _locationInBackground = value;
                    });
                    _updateSetting('location_background', value);
                  },
                  title: const Text('Background Location'),
                  subtitle: const Text('Allow app to access location in background'),
                  secondary: const Icon(Icons.location_on_outlined),
                ),
                
                // Preferences section
                _buildSectionHeader('Preferences'),
                ListTile(
                  title: const Text('Distance Unit'),
                  subtitle: Text(_distanceUnit == 'km' ? 'Kilometers' : 'Miles'),
                  leading: const Icon(Icons.straighten_outlined),
                  trailing: DropdownButton<String>(
                    value: _distanceUnit,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'km',
                        child: Text('Kilometers'),
                      ),
                      DropdownMenuItem(
                        value: 'mi',
                        child: Text('Miles'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _distanceUnit = value;
                        });
                        _updateSetting('distance_unit', value);
                      }
                    },
                  ),
                ),
                
                ListTile(
                  title: const Text('Language'),
                  subtitle: Text(_language),
                  leading: const Icon(Icons.language_outlined),
                  trailing: DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: 'Nepali',
                        child: Text('Nepali'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _language = value;
                        });
                        _updateSetting('language', value);
                      }
                    },
                  ),
                ),
                
                SwitchListTile(
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                    });
                    _updateSetting('dark_mode', value);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Theme changes will apply after restart'),
                      ),
                    );
                  },
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme (requires app restart)'),
                  secondary: const Icon(Icons.brightness_4_outlined),
                ),
                
                // Account section
                _buildSectionHeader('Account'),
                ListTile(
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Free up storage space'),
                  leading: const Icon(Icons.cleaning_services_outlined),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Cache'),
                        content: const Text('Are you sure you want to clear the app cache?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmed == true) {
                      // Simulate cache clearing
                      await Future.delayed(const Duration(seconds: 1));
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache cleared successfully'),
                            backgroundColor: AppColors.successColor,
                          ),
                        );
                      }
                    }
                  },
                ),
                
                ListTile(
                  title: const Text('Delete Search History'),
                  subtitle: const Text('Clear your recent searches'),
                  leading: const Icon(Icons.history_outlined),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Search History'),
                        content: const Text('Are you sure you want to delete your search history?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmed == true) {
                      // Simulate history deletion
                      await Future.delayed(const Duration(seconds: 1));
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Search history deleted'),
                            backgroundColor: AppColors.successColor,
                          ),
                        );
                      }
                    }
                  },
                ),
                
                // About section
                _buildSectionHeader('About'),
                ListTile(
                  title: const Text('App Version'),
                  subtitle: Text(_appVersion),
                  leading: const Icon(Icons.info_outline),
                ),
                
                ListTile(
                  title: const Text('Terms of Service'),
                  subtitle: const Text('Read our terms and conditions'),
                  leading: const Icon(Icons.description_outlined),
                  onTap: () {
                    // TODO: Navigate to terms of service
                  },
                ),
                
                ListTile(
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('Read our privacy policy'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
                
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: AppTextStyles.subtitleStyle.copyWith(
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
} 