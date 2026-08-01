import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  // Picks up android/app/google-services.json natively — no FirebaseOptions needed on Android.
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MoneyFlowApp()));
}
