import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shake/shake.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'dart:async';

import 'app.dart';
import 'models/the_user.dart';
import 'screens/chat.dart';
import 'screens/home/home.dart';
import 'services/auth.dart';
import 'wrapper.dart';

// Define background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class Routes {
  static const String app = '/app';
  static const String wrapper = '/wrapper';
  static const String home = '/home';
  static const String chat = '/chat';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    // Initialize Firebase Messaging
    final fcm = FirebaseMessaging.instance;

    // Request notification permissions
    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await fcm.getToken();
    debugPrint('FCM Token: $token');

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    runApp(const MyApp());
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamProvider<TheUser?>.value(
      value: AuthService().user,
      initialData: null,
      catchError: (_, __) => null,
      child: MaterialApp(
        initialRoute: Routes.wrapper,
        routes: {
          Routes.app: (context) => const App(),
          Routes.wrapper: (context) => const ShakeDetectorWrapper(),
          Routes.home: (context) => HomePage(),
          Routes.chat: (context) => Chat(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ShakeDetectorWrapper extends StatefulWidget {
  const ShakeDetectorWrapper({Key? key}) : super(key: key);

  @override
  _ShakeDetectorWrapperState createState() => _ShakeDetectorWrapperState();
}

class _ShakeDetectorWrapperState extends State<ShakeDetectorWrapper> {
  ShakeDetector? _shakeDetector;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  Timer? _listeningTimer;
  bool _speechInitialized = false;
  List<String> _emergencyContacts = [];
  int _shakeCount = 0;
  Timer? _shakeResetTimer;
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
    _initSpeechRecognition();
    _initShakeDetector();
  }

  Future<void> _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyContacts = prefs.getStringList('emergency_contacts') ?? [];
    });
    debugPrint('Loaded ${_emergencyContacts.length} emergency contacts');
  }

  Future<void> _initSpeechRecognition() async {
    try {
      _speechInitialized = await _speech.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' && _isListening) {
            _startListening();
          }
        },
      );
      if (!_speechInitialized) {
        debugPrint('Speech recognition failed to initialize');
      }
    } catch (e) {
      debugPrint('Speech recognition initialization error: $e');
    }
  }

  void _initShakeDetector() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        _shakeCount++;

        // Reset the shake count after 3 seconds
        _shakeResetTimer?.cancel();
        _shakeResetTimer = Timer(const Duration(seconds: 3), () {
          _shakeCount = 0;
        });

        if (_shakeCount >= 2) {
          debugPrint("Shake detected twice! Triggering SOS...");
          _startBackgroundListening();
          _shakeCount = 0; // Reset count
        }
      },
      shakeSlopTimeMS: 500,
      shakeThresholdGravity: 2.7,
    );
  }

  void _startBackgroundListening() {
    if (_isListening) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Mode Activated - Listening for 5 seconds'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _isListening = true);

    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 5), () {
      _stopListening();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS Monitoring Deactivated'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    });

    _startListening();
  }

  void _startListening() {
    if (!_speechInitialized || !_isListening) return;

    _speech.listen(
      onResult: (result) {
        final recognizedWords = result.recognizedWords.toLowerCase();
        debugPrint('Recognized: $recognizedWords');

        if (recognizedWords.contains('help') ||
            recognizedWords.contains('danger') ||
            recognizedWords.contains('emergency') ||
            recognizedWords.contains('sos')) {
          _triggerSOS();
        }
      },
      listenFor: const Duration(seconds: 2),
      pauseFor: const Duration(seconds: 1),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    _listeningTimer?.cancel();
  }

  Future<void> _triggerSOS() async {
    _stopListening();

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _sendSOSWithLocation(position);
    } catch (e) {
      debugPrint('Error getting location: $e');
      _sendSOSWithoutLocation();
    }
  }

  Future<void> _sendSOSWithLocation(Position position) async {
    if (_emergencyContacts.isEmpty) return;

    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final String message = 'EMERGENCY! I need help! My location: $googleMapsUrl';

    await _sendSMS(message, _emergencyContacts);
    debugPrint("SOS alert sent with location.");
  }

  Future<void> _sendSOSWithoutLocation() async {
    if (_emergencyContacts.isEmpty) return;

    final String message = 'EMERGENCY! I need help! (Location unavailable)';

    await _sendSMS(message, _emergencyContacts);
    debugPrint("SOS alert sent without location.");
  }

  Future<void> _sendSMS(String message, List<String> recipients) async {
    // Request SMS permissions
    final bool? permissionsGranted = await telephony.requestSmsPermissions;

    if (permissionsGranted == true) {
      for (String recipient in recipients) {
        await telephony.sendSms(
          to: recipient,
          message: message,
        );
      }
    } else {
      debugPrint("SMS permissions not granted.");
    }
  }

  @override
  void dispose() {
    _stopListening();
    _shakeDetector?.stopListening();
    _listeningTimer?.cancel();
    _shakeResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Wrapper();
  }
}