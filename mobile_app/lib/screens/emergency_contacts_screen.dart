import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/app_theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // ============================================================
  // LOAD CONTACTS
  // ============================================================

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result = await ApiService.getEmergencyContacts();

      if (!mounted) return;

      if (result["success"] == true) {
        final data = result["contacts"];

        List<Map<String, dynamic>> contacts = [];

        if (data is List) {
          contacts = data
              .map(
                (item) => Map<String, dynamic>.from(item as Map),
              )
              .toList();
        }

        setState(() {
          _contacts = contacts;
          _loading = false;
        });
      } else {
        setState(() {
          _contacts = [];
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result["message"] ?? "Unable to load contacts.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load contacts: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // ADD CONTACT
  // ============================================================

  Future<void> _showAddContactDialog() async {
    if (_contacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Maximum of 3 emergency contacts allowed.",
          ),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "Add Emergency Contact",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !saving,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Name",
                        hintText: "Enter contact name",
                        prefixIcon:
                            Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: emailController,
                      enabled: !saving,
                      keyboardType:
                          TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        hintText: "Enter email address",
                        prefixIcon:
                            Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: phoneController,
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone (optional)",
                        hintText: "Enter phone number",
                        prefixIcon:
                            Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name =
                              nameController.text.trim();

                          final email =
                              emailController.text.trim();

                          final phone =
                              phoneController.text.trim();

                          // ------------------------------
                          // VALIDATION
                          // ------------------------------

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter the contact name.",
                                ),
                              ),
                            );
                            return;
                          }

                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter the email address.",
                                ),
                              ),
                            );
                            return;
                          }

                          // Basic email validation
                          if (!email.contains("@") ||
                              !email.contains(".")) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter a valid email address.",
                                ),
                              ),
                            );
                            return;
                          }

                          // ------------------------------
                          // START SAVING
                          // ------------------------------

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final result =
                                await ApiService
                                    .addEmergencyContact(
                              name: name,
                              email: email,
                              phone: phone.isEmpty
                                  ? null
                                  : phone,
                            );

                            if (!context.mounted) return;

                            if (result["success"] == true) {
                              Navigator.pop(dialogContext);

                              await _loadContacts();

                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result["message"] ??
                                        "Emergency contact added successfully.",
                                  ),
                                ),
                              );
                            } else {
                              setDialogState(() {
                                saving = false;
                              });

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result["message"] ??
                                        "Unable to add contact.",
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;

                            setDialogState(() {
                              saving = false;
                            });

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Failed to add contact: $e",
                                ),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  // ============================================================
  // DELETE CONTACT
  // ============================================================

  Future<void> _deleteContact(int contactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Contact"),
          content: const Text(
            "Are you sure you want to delete this emergency contact?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result =
          await ApiService.deleteEmergencyContact(
        contactId,
      );

      if (!mounted) return;

      if (result["success"] == true) {
        await _loadContacts();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result["message"] ??
                  "Emergency contact deleted successfully.",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result["message"] ??
                  "Unable to delete contact.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete contact: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final maximumReached = _contacts.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed:
            maximumReached ? null : _showAddContactDialog,
        backgroundColor: maximumReached
            ? Colors.grey
            : AppTheme.accent,
        child: const Icon(Icons.add),
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accent,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadContacts,
              color: AppTheme.accent,

              child: _contacts.isEmpty
                  ? _buildEmptyState()
                  : _buildContactsList(),
            ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      children: const [
        SizedBox(height: 100),

        Icon(
          Icons.people_outline,
          size: 70,
          color: AppTheme.textLight,
        ),

        SizedBox(height: 16),

        Center(
          child: Text(
            "No emergency contacts added",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(height: 8),

        Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              "Add trusted people who should receive an emergency alert when danger is detected.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textLight,
              ),
            ),
          ),
        ),

        SizedBox(height: 30),
      ],
    );
  }

  // ============================================================
  // CONTACT LIST
  // ============================================================

  Widget _buildContactsList() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.all(16),

      children: [
        Text(
          "${_contacts.length}/3 Emergency Contacts",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          "These contacts receive emergency email alerts when the AI detects possible danger.",
          style: TextStyle(
            color: AppTheme.textLight,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 20),

        ..._contacts.map(
          (contact) {
            final id = _getContactId(contact);

            return _ContactCard(
              contact: contact,
              onDelete: id == null
                  ? null
                  : () => _deleteContact(id),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // SAFELY GET CONTACT ID
  // ============================================================

  int? _getContactId(
    Map<String, dynamic> contact,
  ) {
    final value = contact["id"];

    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}

// ================================================================
// CONTACT CARD
// ================================================================

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback? onDelete;

  const _ContactCard({
    required this.contact,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        contact["name"]?.toString() ?? "";

    final email =
        contact["email"]?.toString() ?? "";

    final phone =
        contact["phone"]?.toString() ?? "";

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding:
            const EdgeInsets.all(16),

        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,

          children: [
            // --------------------------------------------------
            // PERSON ICON
            // --------------------------------------------------

            Container(
              width: 50,
              height: 50,

              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius:
                    BorderRadius.circular(25),
              ),

              child: const Icon(
                Icons.person,
                color: AppTheme.accent,
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            // --------------------------------------------------
            // CONTACT DETAILS
            // --------------------------------------------------

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    name.isEmpty
                        ? "Unknown Contact"
                        : name,

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    email,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,

                    style: const TextStyle(
                      color:
                          AppTheme.textLight,
                      fontSize: 13,
                    ),
                  ),

                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),

                    Text(
                      phone,
                      style: const TextStyle(
                        color:
                            AppTheme.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // --------------------------------------------------
            // DELETE BUTTON
            // --------------------------------------------------

            IconButton(
              onPressed: onDelete,

              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),

              tooltip: "Delete",
            ),
          ],
        ),
      ),
    );
  }
}