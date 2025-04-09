import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  String _searchQuery = '';
  String _filterRole = 'All'; // 'All', 'Passenger', 'Rider'
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters and search info
          if (_searchQuery.isNotEmpty || _filterRole != 'All')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceColor,
              child: Row(
                children: [
                  if (_searchQuery.isNotEmpty)
                    Expanded(
                      child: Chip(
                        label: Text('Search: $_searchQuery'),
                        onDeleted: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                    ),
                  if (_filterRole != 'All')
                    Expanded(
                      child: Chip(
                        label: Text('Role: $_filterRole'),
                        onDeleted: () {
                          setState(() {
                            _filterRole = 'All';
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildUserQuery(),
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

                final users = snapshot.data?.docs ?? [];

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: AppTextStyles.subtitleStyle,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final user = UserModel.fromMap(userData);

                    return _buildUserCard(user, users[index].id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build the Firestore query based on filters
  Stream<QuerySnapshot> _buildUserQuery() {
    Query query = FirebaseFirestore.instance.collection('users');

    // Apply role filter
    if (_filterRole == 'Passenger') {
      query = query.where('userRole', isEqualTo: 'passenger');
    } else if (_filterRole == 'Rider') {
      query = query.where('userRole', isEqualTo: 'rider');
    }

    // Apply search if present
    // Note: Firestore doesn't support direct text search, so we're using startAt/endAt for prefix search
    if (_searchQuery.isNotEmpty) {
      // This is a simple prefix search on name
      query = query.orderBy('name')
          .startAt([_searchQuery])
          .endAt(['$_searchQuery\uf8ff']);
    }

    return query.snapshots();
  }

  // Build a card for a single user
  Widget _buildUserCard(UserModel user, String docId) {
    final bool isRider = user.userRole == UserRole.rider;
    final String riderStatusLabel = user.riderStatus ?? 'not_applied';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isRider ? AppColors.accentColor : AppColors.primaryColor,
                  child: Icon(
                    isRider ? Icons.directions_car : Icons.person,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name ?? 'No Name',
                        style: AppTextStyles.bodyBoldStyle,
                      ),
                      Text(
                        user.phoneNumber,
                        style: AppTextStyles.captionStyle,
                      ),
                    ],
                  ),
                ),
                // Status chip
                Chip(
                  label: Text(
                    isRider ? 'Rider' : 'Passenger',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: isRider
                      ? AppColors.accentColor
                      : AppColors.primaryColor,
                ),
              ],
            ),
            if (riderStatusLabel != 'not_applied')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Text(
                      'Rider Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        _formatRiderStatus(riderStatusLabel),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: _getRiderStatusColor(riderStatusLabel),
                    ),
                  ],
                ),
              ),
            if (user.dateOfBirth != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'DOB: ${_formatDate(user.dateOfBirth!)}',
                  style: AppTextStyles.captionStyle,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View detailed profile button
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Profile'),
                  onPressed: () => _showUserDetails(user),
                ),
                const SizedBox(width: 8),
                // Edit user status button
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Status'),
                  onPressed: () => _showEditStatusDialog(user, docId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Format rider status for display
  String _formatRiderStatus(String status) {
    return status.substring(0, 1).toUpperCase() + status.substring(1);
  }

  // Get color based on rider status
  Color _getRiderStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.successColor;
      case 'pending':
        return AppColors.warningColor;
      case 'rejected':
        return AppColors.errorColor;
      default:
        return AppColors.secondaryTextColor;
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Show search dialog
  void _showSearchDialog() {
    final TextEditingController controller = TextEditingController(text: _searchQuery);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Users'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter name to search',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Search'),
            onPressed: () {
              setState(() {
                _searchQuery = controller.text.trim();
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Show filter dialog
  void _showFilterDialog() {
    String tempFilter = _filterRole;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Role'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('All Users'),
                  value: 'All',
                  groupValue: tempFilter,
                  onChanged: (value) {
                    setState(() {
                      tempFilter = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Passengers Only'),
                  value: 'Passenger',
                  groupValue: tempFilter,
                  onChanged: (value) {
                    setState(() {
                      tempFilter = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Riders Only'),
                  value: 'Rider',
                  groupValue: tempFilter,
                  onChanged: (value) {
                    setState(() {
                      tempFilter = value!;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Apply'),
            onPressed: () {
              setState(() {
                _filterRole = tempFilter;
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Show user details dialog
  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name ?? 'User Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text('Phone Number'),
                subtitle: Text(user.phoneNumber),
                leading: const Icon(Icons.phone),
              ),
              if (user.dateOfBirth != null)
                ListTile(
                  title: const Text('Date of Birth'),
                  subtitle: Text(_formatDate(user.dateOfBirth!)),
                  leading: const Icon(Icons.calendar_today),
                ),
              ListTile(
                title: const Text('User Role'),
                subtitle: Text(user.userRole == UserRole.rider ? 'Rider' : 'Passenger'),
                leading: const Icon(Icons.person),
              ),
              if (user.riderStatus != null && user.riderStatus != 'not_applied')
                ListTile(
                  title: const Text('Rider Status'),
                  subtitle: Text(_formatRiderStatus(user.riderStatus!)),
                  leading: const Icon(Icons.verified_user),
                ),
              ListTile(
                title: const Text('Joined On'),
                subtitle: Text(_formatDate(user.createdAt)),
                leading: const Icon(Icons.access_time),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Show edit status dialog
  void _showEditStatusDialog(UserModel user, String docId) {
    String selectedRole = user.userRole == UserRole.rider ? 'rider' : 'passenger';
    String selectedRiderStatus = user.riderStatus ?? 'not_applied';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Status'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'User Role',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
                    DropdownMenuItem(value: 'rider', child: Text('Rider')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Rider Status',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedRiderStatus,
                  items: const [
                    DropdownMenuItem(value: 'not_applied', child: Text('Not Applied')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRiderStatus = value!;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });

              try {
                // Update user role
                final userRole = selectedRole == 'rider' ? UserRole.rider : UserRole.passenger;
                await _authService.updateUserRole(
                  uid: docId,
                  newRole: userRole,
                );

                // Update rider status
                await _authService.updateUserRiderStatus(
                  uid: docId,
                  newStatus: selectedRiderStatus,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User status updated successfully'),
                      backgroundColor: AppColors.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating user: $e'),
                      backgroundColor: AppColors.errorColor,
                    ),
                  );
                }
              } finally {
                setState(() {
                  _isLoading = false;
                });
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ],
      ),
    );
  }
} 