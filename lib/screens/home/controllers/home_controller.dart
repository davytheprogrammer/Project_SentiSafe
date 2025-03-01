import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeController extends ChangeNotifier {
  DateTime? sobrietyStartDate;
  int currentMilestone = 1;
  bool hasCheckedInToday = false;
  int totalCheckIns = 0;
  DateTime? lastCheckInDate;
  late SharedPreferences prefs;
  final List<int> milestones = [1, 7, 14, 21, 30, 60, 90, 180, 365];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userId;
  Timer? _dateChecker;
  int? _lastCelebratedDays;

  Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();
    await _getUserId();
    if (userId != null) {
      await _syncDataFromFirebase();
      String? startDateStr = prefs.getString('sobriety_start_date');
      String? lastCheckInStr = prefs.getString('last_check_in_date');
      sobrietyStartDate = startDateStr != null ? DateTime.parse(startDateStr) : null;
      lastCheckInDate = lastCheckInStr != null ? DateTime.parse(lastCheckInStr) : null;
      totalCheckIns = prefs.getInt('total_check_ins') ?? 0;
      hasCheckedInToday = _hasCheckedInToday();
      _lastCelebratedDays = prefs.getInt('last_celebrated_days');
      _updateMilestone();
      _startDateChecker();
    }
    notifyListeners();
  }

  bool shouldCelebrate() {
    if (totalCheckIns == 0) return false;

    // Don't celebrate if we've already celebrated this milestone
    if (_lastCelebratedDays == totalCheckIns) return false;

    // Check if current days matches any milestone
    bool shouldCelebrate = milestones.contains(totalCheckIns);

    // Also celebrate every additional month (30 days) after 365 days
    if (totalCheckIns > 365) {
      shouldCelebrate = shouldCelebrate || (totalCheckIns % 30 == 0);
    }

    // If we should celebrate, store this milestone
    if (shouldCelebrate) {
      _lastCelebratedDays = totalCheckIns;
      prefs.setInt('last_celebrated_days', totalCheckIns);
    }

    return shouldCelebrate;
  }

  Future<void> _getUserId() async {
    User? user = _auth.currentUser;
    userId = user?.uid;
  }

  Future<void> _syncDataFromFirebase() async {
    try {
      if (userId == null) return;

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        String? firebaseStartDate = data['sobriety_start_date'];
        bool firebaseCheckedInToday = data['has_checked_in_today'] ?? false;
        int firebaseTotalCheckIns = data['total_check_ins'] ?? 0;
        String? firebaseLastCheckIn = data['last_check_in_date'];

        await prefs.setString('sobriety_start_date', firebaseStartDate ?? '');
        await prefs.setInt('total_check_ins', firebaseTotalCheckIns);
        await prefs.setString('last_check_in_date', firebaseLastCheckIn ?? '');
        await prefs.setBool(
          'checkin_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
          firebaseCheckedInToday,
        );
      } else {
        await _firestore.collection('users').doc(userId).set({
          'sobriety_start_date': '',
          'has_checked_in_today': false,
          'total_check_ins': 0,
          'last_check_in_date': '',
        });
      }
    } catch (e) {
      print('Error syncing data from Firebase: $e');
    }
  }

  Future<void> _syncDataToFirebase() async {
    try {
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'sobriety_start_date': sobrietyStartDate?.toIso8601String() ?? '',
        'has_checked_in_today': hasCheckedInToday,
        'total_check_ins': totalCheckIns,
        'last_check_in_date': lastCheckInDate?.toIso8601String() ?? '',
      });
    } catch (e) {
      print('Error syncing data to Firebase: $e');
    }
  }

  bool _hasCheckedInToday() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return prefs.getBool('checkin_$today') ?? false;
  }

  void _startDateChecker() {
    _dateChecker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_hasDateChanged()) {
        _handleNewDay();
      }
    });
  }

  bool _hasDateChanged() {
    final lastCheck = prefs.getString('last_date_check');
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return lastCheck != currentDate;
  }

  Future<bool> checkMissedDay(BuildContext context) async {
    if (lastCheckInDate == null) return false;

    final today = DateTime.now();
    final difference = today.difference(lastCheckInDate!).inDays;

    if (difference > 1) {
      bool shouldReset = await _showMissedDayDialog(context);
      return shouldReset;
    }
    return false;
  }

  Future<bool> _showMissedDayDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Missed Check-in', style: GoogleFonts.poppins()),
        content: Text(
          'We noticed you missed checking in yesterday. Were you loyal to your plan, or did you relapse? Please be honest with yourself.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('I Relapsed', style: GoogleFonts.poppins(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('I Stayed Sober', style: GoogleFonts.poppins(color: Colors.green)),
          ),
        ],
      ),
    );

    return result ?? true; // Default to reset if dialog is dismissed
  }

  void _handleNewDay() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('last_date_check', today);
    hasCheckedInToday = false;
    notifyListeners();
  }

  void _updateMilestone() {
    if (sobrietyStartDate == null) return;
    int daysSober = totalCheckIns;
    for (int milestone in milestones.reversed) {
      if (daysSober >= milestone) {
        currentMilestone = milestone;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> checkIn(BuildContext context) async {
    if (hasCheckedInToday) return;

    // Check for missed days
    if (await checkMissedDay(context)) {
      await _resetData();
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (sobrietyStartDate == null) {
      sobrietyStartDate = DateTime.parse(today);
      await prefs.setString('sobriety_start_date', today);
    }

    totalCheckIns++;
    lastCheckInDate = DateTime.now();

    await prefs.setInt('total_check_ins', totalCheckIns);
    await prefs.setString('last_check_in_date', lastCheckInDate!.toIso8601String());
    await prefs.setBool('checkin_$today', true);

    hasCheckedInToday = true;
    _updateMilestone();
    await _syncDataToFirebase();
    notifyListeners();
  }

  int getDaysSober() {
    return totalCheckIns;
  }

  Future<void> handleRelapse(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Beginning', style: GoogleFonts.poppins()),
        content: Text(
          "It's okay to start fresh. Remember, every day is a new opportunity.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _resetData();
    }
  }

  Future<void> _resetData() async {
    await prefs.remove('sobriety_start_date');
    await prefs.remove('last_celebrated_days');
    await prefs.remove('total_check_ins');
    await prefs.remove('last_check_in_date');
    await _resetCheckins();

    sobrietyStartDate = null;
    hasCheckedInToday = false;
    _lastCelebratedDays = null;
    totalCheckIns = 0;
    lastCheckInDate = null;

    await _syncDataToFirebase();
    notifyListeners();
  }

  Future<void> _resetCheckins() async {
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('checkin_')) {
        await prefs.remove(key);
      }
    }
  }

  @override
  void dispose() {
    _dateChecker?.cancel();
    super.dispose();
  }
}