import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Goals extends StatefulWidget {
  const Goals({Key? key}) : super(key: key);

  @override
  State<Goals> createState() => _GoalsState();
}

class _GoalsState extends State<Goals> with TickerProviderStateMixin {
  final List<Goal> _goals = [];
  late SharedPreferences _prefs;
  late AnimationController _addButtonController;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _addButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadGoals();
  }

  void _loadGoals() {
    final goalsJson = _prefs.getStringList('goals') ?? [];
    setState(() {
      _goals.clear();
      for (var goalStr in goalsJson) {
        _goals.add(Goal.fromJson(json.decode(goalStr)));
      }
      _isLoading = false;
    });
  }

  Future<void> _saveGoals() async {
    final goalsJson = _goals.map((goal) =>
        json.encode(goal.toJson())).toList();
    await _prefs.setStringList('goals', goalsJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FACFE)))
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Recovery Goals',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.stars,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                if (index >= _goals.length) return null;
                final goal = _goals[index];
                final progress = goal.calculateProgress();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2A2A3E),
                          const Color(0xFF2A2A3E).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4FACFE).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        goal.title,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Target: ${goal.target} ${goal.unit}',
                            style: GoogleFonts.orbitron(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getProgressColor(progress),
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Due: ${DateFormat('MMM dd, yyyy').format(goal.deadline)}',
                            style: GoogleFonts.orbitron(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF4FACFE)),
                        onPressed: () => _editGoal(goal, index),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _addButtonController,
            curve: Curves.elasticOut,
          ),
        ),
        child: FloatingActionButton(
          onPressed: _addNewGoal,
          backgroundColor: const Color(0xFF4FACFE),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.7) return Colors.orange;
    return Colors.green;
  }

  void _addNewGoal() {
    _showGoalDialog(null);
  }

  void _editGoal(Goal goal, int index) {
    _showGoalDialog(goal, index: index);
  }

  void _showGoalDialog(Goal? goal, {int? index}) {
    final isEditing = goal != null;
    final titleController = TextEditingController(text: goal?.title ?? '');
    final targetController = TextEditingController(
      text: goal?.target.toString() ?? '',
    );
    final currentController = TextEditingController(
      text: goal?.current.toString() ?? '0',
    );
    final unitController = TextEditingController(text: goal?.unit ?? '');
    DateTime selectedDate = goal?.deadline ?? DateTime.now().add(
      const Duration(days: 30),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          isEditing ? 'Edit Goal' : 'New Goal',
          style: GoogleFonts.orbitron(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  style: GoogleFonts.orbitron(color: Colors.white),
                  decoration: _buildInputDecoration('Goal Title'),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: targetController,
                        style: GoogleFonts.orbitron(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('Target'),
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please enter a target'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: unitController,
                        style: GoogleFonts.orbitron(color: Colors.white),
                        decoration: _buildInputDecoration('Unit'),
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Enter unit' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: currentController,
                  style: GoogleFonts.orbitron(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Current Progress'),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Enter progress' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    'Deadline: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                    style: GoogleFonts.orbitron(color: Colors.white),
                  ),
                  trailing: Icon(
                    Icons.calendar_today,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF4FACFE),
                              surface: Color(0xFF2A2A3E),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.orbitron(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FACFE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                final newGoal = Goal(
                  title: titleController.text,
                  target: double.parse(targetController.text),
                  current: double.parse(currentController.text),
                  unit: unitController.text,
                  deadline: selectedDate,
                );

                setState(() {
                  if (isEditing) {
                    _goals[index!] = newGoal;
                  } else {
                    _goals.add(newGoal);
                  }
                });

                _saveGoals();
                Navigator.pop(context);
              }
            },
            child: Text(
              isEditing ? 'Update' : 'Create',
              style: GoogleFonts.orbitron(),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.orbitron(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF4FACFE)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  @override
  void dispose() {
    _addButtonController.dispose();
    super.dispose();
  }
}

class Goal {
  final String title;
  final double target;
  final double current;
  final String unit;
  final DateTime deadline;

  Goal({
    required this.title,
    required this.target,
    required this.current,
    required this.unit,
    required this.deadline,
  });

  double calculateProgress() {
    return (current / target).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'target': target,
      'current': current,
      'unit': unit,
      'deadline': deadline.toIso8601String(),
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      title: json['title'],
      target: json['target'],
      current: json['current'],
      unit: json['unit'],
      deadline: DateTime.parse(json['deadline']),
    );
  }
}