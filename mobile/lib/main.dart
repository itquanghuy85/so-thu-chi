import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/notifications/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  try {
    // Explicit options (see firebase_options.dart's doc comment) so this
    // doesn't depend on the native config file being correctly bundled by
    // the platform build — previously an un-bundled iOS
    // GoogleService-Info.plist made this throw before runApp(), which is
    // why the app showed a blank white screen on iOS specifically.
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    // Defense in depth: if Firebase init ever fails again for some other
    // reason (bad network on first launch, misconfigured project, ...),
    // show a legible error instead of leaving the screen blank with no way
    // to tell what happened.
    runApp(_FirebaseInitErrorApp(error: error));
    return;
  }
  runApp(const ProviderScope(child: MoneyFlowApp()));
}

class _FirebaseInitErrorApp extends StatelessWidget {
  final Object error;

  const _FirebaseInitErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Không thể khởi động ứng dụng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
