import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';

import '../../../core/safety_plan_model.dart';
import '../../../core/safety_plan_provider.dart';

class SafetyPlanEditor extends StatefulWidget {
  const SafetyPlanEditor({super.key});

  @override
  State<SafetyPlanEditor> createState() => _SafetyPlanEditorState();
}

class _SafetyPlanEditorState extends State<SafetyPlanEditor>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _safeWordController = TextEditingController();
  late AnimationController _animationController;
  bool _isFormExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingPlan());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadExistingPlan() {
    final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
    final plan = provider.safetyPlan;
    if (plan != null) {
      _safeWordController.text = plan.safeWord;
    }
  }

  void _saveContact() {
    if (_formKey.currentState!.validate()) {
      final contact = EmergencyContact(
        name: _nameController.text,
        phone: _phoneController.text,
        relationship: _relationshipController.text,
      );

      final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
      final existingPlan = provider.safetyPlan ??
          SafetyPlan(
            contacts: [],
            safeWord: _safeWordController.text,
          );

      final newPlan = SafetyPlan(
        contacts: [...existingPlan.contacts, contact],
        safeWord: _safeWordController.text,
      );

      provider.saveSafetyPlan(newPlan);
      _clearForm();
      _toggleForm();
    }
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _relationshipController.clear();
  }

  void _toggleForm() {
    setState(() {
      _isFormExpanded = !_isFormExpanded;
      if (_isFormExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Safety Plan',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSafeWordCard(),
                  const SizedBox(height: 20),
                  _buildContactsSection(size),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleForm,
        icon: Icon(_isFormExpanded ? Icons.close : Icons.add),
        label: Text(_isFormExpanded ? 'Close' : 'Add Contact'),
      ),
    );
  }

  Widget _buildSafeWordCard() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 120,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: TextFormField(
          controller: _safeWordController,
          style: GoogleFonts.poppins(fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Emergency Safe Word',
            labelStyle: GoogleFonts.poppins(),
            prefixIcon: const Icon(Icons.security),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          validator: (value) => value!.isEmpty ? 'Required field' : null,
        ),
      ),
    ).animate().fade(duration: 500.ms).scale(delay: 100.ms);
  }

  Widget _buildContactsSection(Size size) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isFormExpanded ? null : 0,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildAnimatedTextField(
                  controller: _nameController,
                  label: 'Contact Name',
                  icon: Icons.person,
                  delay: 0,
                ),
                const SizedBox(height: 15),
                _buildAnimatedTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  delay: 100,
                ),
                const SizedBox(height: 15),
                _buildAnimatedTextField(
                  controller: _relationshipController,
                  label: 'Relationship',
                  icon: Icons.group,
                  delay: 200,
                ),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildContactsList(),
      ],
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required int delay,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      validator: (value) => value!.isEmpty ? 'Required field' : null,
    )
        .animate()
        .fade(delay: Duration(milliseconds: delay))
        .slideX(delay: Duration(milliseconds: delay));
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save),
        label: Text('Save Contact', style: GoogleFonts.poppins(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _saveContact,
      ),
    ).animate().fade(delay: 300.ms).slideY(delay: 300.ms);
  }

  Widget _buildContactsList() {
    return Consumer<SafetyPlanProvider>(
      builder: (context, provider, _) {
        final contacts = provider.safetyPlan?.contacts ?? [];

        if (contacts.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text(
                  'No contacts added yet',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ).animate().fade().scale();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    contact.name[0].toUpperCase(),
                    style: GoogleFonts.poppins(),
                  ),
                ),
                title: Text(
                  contact.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.phone),
                    Text(
                      contact.relationship,
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () => _deleteContact(contact),
                ),
              ),
            )
                .animate()
                .fade(delay: Duration(milliseconds: index * 100))
                .slideX(delay: Duration(milliseconds: index * 100));
          },
        );
      },
    );
  }

  void _deleteContact(EmergencyContact contact) {
    final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
    final newContacts = provider.safetyPlan!.contacts
      ..removeWhere((c) => c.phone == contact.phone);

    provider.saveSafetyPlan(SafetyPlan(
      contacts: newContacts,
      safeWord: provider.safetyPlan!.safeWord,
    ));
  }
}
