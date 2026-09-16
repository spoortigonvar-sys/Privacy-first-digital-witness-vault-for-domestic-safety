import 'package:flutter/material.dart';

import 'utils/app_theme.dart';
import 'models/evidence_model.dart';

import 'screens/calculator_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/recorder_screen.dart';
import 'screens/evidence_history_screen.dart';
import 'screens/evidence_detail_screen.dart';
import 'screens/verify_evidence_screen.dart';

import 'stealth/stealth_controller.dart';
import 'utils/constants.dart';

void main() {
  runApp(const DigitalWitnessVaultApp());
}

class DigitalWitnessVaultApp extends StatelessWidget {
  const DigitalWitnessVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      
      theme: AppTheme.theme,

      navigatorKey: StealthController.instance.navigatorKey,

      home: const CalculatorScreen(),

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppConstants.loginRoute:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );

          case AppConstants.registerRoute:
            return MaterialPageRoute(
              builder: (_) => const RegisterScreen(),
            );

          case AppConstants.dashboardRoute:
            return MaterialPageRoute(
              builder: (_) => const DashboardScreen(),
            );

          case AppConstants.uploadRoute:
            return MaterialPageRoute(
              builder: (_) => const UploadScreen(),
            );

          case AppConstants.recorderRoute:
            return MaterialPageRoute(
              builder: (_) => const RecorderScreen(),
            );

          case AppConstants.historyRoute:
            return MaterialPageRoute(
              builder: (_) => const EvidenceHistoryScreen(),
            );

          case AppConstants.verifyRoute:
            return MaterialPageRoute(
              builder: (_) => const VerifyEvidenceScreen(),
            );

          case AppConstants.evidenceDetailRoute:
            final evidence = settings.arguments as EvidenceModel;
            return MaterialPageRoute(
              builder: (_) => EvidenceDetailScreen(
                evidence: evidence,
              ),
            );
        }

        return null;
      },
    );
  }
}