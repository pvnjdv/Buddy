import 'package:flutter/material.dart';
import '../../services/contact_service.dart';

class ContactSelectionScreen extends StatefulWidget {
  const ContactSelectionScreen({super.key});

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  List<Map<String, dynamic>> allContacts = [];
  List<Map<String, dynamic>> filteredContacts = [];
  List<Map<String, dynamic>> selectedContacts = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Request permission
      bool permission = await ContactService.requestContactPermission();
      setState(() {
        hasPermission = permission;
      });

      if (permission) {
        // Load combined contacts (device + backend data)
        List<Map<String, dynamic>> contacts =
            await ContactService.getCombinedContacts();
        setState(() {
          allContacts = contacts;
          filteredContacts = contacts;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _searchContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredContacts = allContacts;
      } else {
        filteredContacts = allContacts.where((contact) {
          String name = (contact['display_name'] ?? '').toLowerCase();
          String phone = (contact['phone_number'] ?? '').toLowerCase();
          String searchQuery = query.toLowerCase();
          return name.contains(searchQuery) || phone.contains(searchQuery);
        }).toList();
      }
    });
  }

  void _toggleContactSelection(Map<String, dynamic> contact) {
    setState(() {
      bool isSelected = selectedContacts.any((c) => c['id'] == contact['id']);
      if (isSelected) {
        selectedContacts.removeWhere((c) => c['id'] == contact['id']);
      } else {
        selectedContacts.add(contact);
      }
    });
  }

  bool _isContactSelected(Map<String, dynamic> contact) {
    return selectedContacts.any((c) => c['id'] == contact['id']);
  }

  void _proceedWithSelectedContacts() {
    if (selectedContacts.isNotEmpty) {
      Navigator.pop(context, selectedContacts);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contacts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (selectedContacts.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${selectedContacts.length}'),
                child: const Icon(Icons.check),
              ),
              onPressed: _proceedWithSelectedContacts,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search contacts',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _searchContacts,
            ),
          ),

          // Permission message
          if (!hasPermission && !isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.contacts, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Contact Permission Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please allow access to contacts to view and select them',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadContacts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading contacts...'),
                  ],
                ),
              ),
            ),

          // Contacts list
          if (!isLoading && hasPermission)
            Expanded(
              child: filteredContacts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No contacts found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final isSelected = _isContactSelected(contact);
                        final isBuddyUser = contact['is_buddy_user'] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: contact['photo'] != null
                                      ? MemoryImage(contact['photo'])
                                      : null,
                                  child: contact['photo'] == null
                                      ? Text(
                                          (contact['display_name'] ?? 'U')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                if (isBuddyUser)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              contact['display_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact['phone_number'] ?? ''),
                                if (isBuddyUser)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Buddy User',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                _toggleContactSelection(contact);
                              },
                              activeColor: Colors.blue,
                            ),
                            onTap: () => _toggleContactSelection(contact),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
      floatingActionButton: selectedContacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _proceedWithSelectedContacts,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat),
              label: Text('Start Chat (${selectedContacts.length})'),
            )
          : null,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
