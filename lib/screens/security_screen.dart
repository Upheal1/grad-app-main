// lib/screens/security_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthModel>(context);
    final email = auth.userEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: email == null ? const Center(child: Text('Not signed in')) : FutureBuilder(
        future: auth.getUserProfile(email),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const CircularProgressIndicator();
          final u = snap.data;
          if (u==null) return const Text('No profile');
          final lastLogin = u['lastLogin'] ?? 'Never';
          final activities = List<String>.from(u['activities'] ?? []);
          final is2fa = u['is2FAEnabled'] == true;
          final isBio = u['isBiometricEnabled'] == true;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [Icon(Icons.lock), SizedBox(width:8), Text('Data encrypted', style: TextStyle(color: Colors.green))]),
                const SizedBox(height:12),
                Text('Last login: $lastLogin'),
                SwitchListTile(
                  title: const Text('Enable 2FA (email OTP)'),
                  value: is2fa,
                  onChanged: (v) => auth.toggle2FA(email, v),
                ),
                SwitchListTile(
                  title: const Text('Enable biometric login'),
                  value: isBio,
                  onChanged: (v) => auth.toggleBiometric(email, v),
                ),
                const SizedBox(height:12),
                const Text('Recent security events:'),
                Expanded(child: ListView.builder(itemCount: activities.length, itemBuilder: (c,i) {
                  final it = activities[i];
                  final isFail = it.toLowerCase().contains('failed') || it.toLowerCase().contains('locked');
                  return ListTile(leading: Icon(isFail?Icons.error:Icons.check, color: isFail?Colors.red:Colors.green), title: Text(it));
                })),
                ElevatedButton(onPressed: () => auth.requestPasswordReset(email), child: const Text('Request password reset (email)')),
              ],
            ),
          );
        },
      ),
    );
  }
}
