package com.moneyflow.mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// biometric prompt (Mục 14 — PIN/Vân tay app lock).
class MainActivity : FlutterFragmentActivity()
