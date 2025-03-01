import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'components/sos_button.dart';
import 'components/contacts_section.dart';
import 'components/safety_features.dart';
import 'services/location_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final List<String> _contacts;
  bool _isSending = false;
  final _scrollController = ScrollController();
  final LocationService _locationService = LocationService();
  final Telephony telephony = Telephony.instance;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _contacts = []; // Initialize the list
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkPermissions();
    await _loadContacts();
    await _locationService.checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool? permissionsGranted =
      await telephony.requestPhoneAndSmsPermissions;
      print('SMS permissions granted: $permissionsGranted');

      if (mounted) {
        setState(() {
          _hasPermissions = permissionsGranted ?? false;
        });
      }
    } catch (e) {
      print('Error checking permissions: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to check SMS permissions');
      }
    }
  }

  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedContacts = prefs.getStringList('emergency_contacts') ?? [];
      print('Loaded contacts: $savedContacts');
      print('Contact list length: ${savedContacts.length}');

      if (mounted) {
        setState(() {
          _contacts.clear();
          _contacts.addAll(savedContacts);
        });
      }
    } catch (e) {
      print('Error loading contacts: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load emergency contacts');
      }
    }
  }

  Future<void> _sendSOS() async {
    if (!_hasPermissions) {
      _showErrorSnackBar('SMS permissions not granted');
      await _checkPermissions();
      return;
    }

    // Create a local copy of contacts to prevent race conditions
    final contactsList = List<String>.from(_contacts);

    if (contactsList.isEmpty) {
      _showErrorSnackBar('Please add emergency contacts first');
      return;
    }

    if (mounted) {
      setState(() => _isSending = true);
    }

    try {
      print('Attempting to send SOS to contacts: $contactsList');

      Position? position;
      try {
        position = await _locationService.getCurrentLocation();
        print(
            'Location obtained: ${position?.latitude}, ${position?.longitude}');
      } catch (e) {
        print('Location error: $e');
        // Continue without location if it fails
      }

      String message = 'EMERGENCY SOS!\n\nI need immediate assistance!';
      if (position != null) {
        message += '\n\nMy current location:\n'
            'https://www.google.com/maps/search/?api=1&query='
            '${position.latitude},${position.longitude}';
      }

      List<String> failedContacts = [];
      for (String contact in contactsList) {
        try {
          print('Sending SMS to: $contact');

          // Validate phone number format
          String sanitizedContact = contact.replaceAll(RegExp(r'[^\d+]'), '');
          if (sanitizedContact.isEmpty) {
            throw Exception('Invalid phone number format');
          }

          await telephony.sendSms(
            to: sanitizedContact,
            message: message,
          );

          print('SMS sent successfully to: $contact');
        } catch (e) {
          print('Failed to send SMS to $contact: $e');
          failedContacts.add(contact);
        }
      }

      if (mounted) {
        if (failedContacts.isEmpty) {
          _showSuccessSnackBar('SOS sent successfully to all contacts');
        } else if (failedContacts.length == contactsList.length) {
          throw Exception('Failed to send SMS to any contact');
        } else {
          _showWarningSnackBar(
              'SOS sent partially. Failed for: ${failedContacts.join(", ")}');
        }
      }
    } catch (e) {
      print('SOS error: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to send SOS message: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSafetyTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safety Tips'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('• Stay aware of your surroundings'),
              SizedBox(height: 8),
              Text('• Keep your emergency contacts updated'),
              SizedBox(height: 8),
              Text('• Share your location with trusted contacts'),
              SizedBox(height: 8),
              Text('• Keep your phone charged'),
              SizedBox(height: 8),
              Text('• Know your emergency exits'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('SMS Permissions'),
                subtitle: Text(_hasPermissions ? 'Granted' : 'Not Granted'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkPermissions,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location Settings'),
                onTap: () async {
                  await _locationService.checkPermissions();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120, // Reduced from 200
            floating: true, // Changed to floating for better UX
            pinned: true,
            elevation: 0, // Modern design often uses less shadow
            stretch: true, // Adds a nice stretch effect
            backgroundColor: Colors.red.shade700, // Direct background color
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16), // Better title positioning
              title: const Text(
                'Personal Safety',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20, // Slightly larger title
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight, // Changed angle for more visual interest
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.red.shade800,
                      Colors.red.shade600,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24.0),
                    child: Icon(
                      Icons.shield, // Added a relevant icon
                      color: Colors.white.withOpacity(0.3), // Subtle icon
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white), // Changed to outline version
                onPressed: () => _showSafetyTips(context),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white), // Changed to outline version
                onPressed: () => _showSettings(context),
                padding: const EdgeInsets.only(right: 16), // Add some padding to the last icon
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SOSButton(
                    onPressed: _sendSOS,
                    isLoading: _isSending,
                  ),
                  const SizedBox(height: 24),
                  ContactsSection(
                    contacts: _contacts,
                    onContactsChanged: _loadContacts,
                  ),
                  const SizedBox(height: 24),
                  const SafetyFeatures(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        ),
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}