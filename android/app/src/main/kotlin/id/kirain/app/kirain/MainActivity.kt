package id.kirain.app.kirain

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth,
// which uses AndroidX BiometricPrompt under the hood.
class MainActivity : FlutterFragmentActivity()
