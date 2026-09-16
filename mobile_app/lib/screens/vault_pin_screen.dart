import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'my_evidence_screen.dart';

class VaultPinScreen extends StatefulWidget {
  const VaultPinScreen({super.key});

  @override
  State<VaultPinScreen> createState() => _VaultPinScreenState();
}

class _VaultPinScreenState extends State<VaultPinScreen> {
  final TextEditingController _pinController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _unlockVault() async {
    final pin = _pinController.text.trim();

    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() {
        _error = 'Enter your 6-digit Vault PIN';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.unlockVault(pin);

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MyEvidenceScreen(),
          ),
        );
      } else {
        setState(() {
          _error = result['message'] ?? 'Invalid Vault PIN';
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Unable to connect to the Vault';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Access'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 72,
              ),

              const SizedBox(height: 24),

              const Text(
                'Digital Witness Vault',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Enter your special 6-digit PIN to access your evidence.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Vault PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _unlockVault,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('UNLOCK VAULT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}