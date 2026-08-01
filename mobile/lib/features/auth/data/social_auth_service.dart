import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when the user closes the provider's sheet/dialog without picking
/// an account — not an error worth showing a SnackBar for.
class SocialSignInCancelled implements Exception {}

/// Wraps the native Google/Apple sign-in flows and Firebase Auth just to get
/// a Firebase ID token; the token itself (not any Firebase user record) is
/// what the backend verifies in `POST /auth/social-login`.
class SocialAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<String> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw SocialSignInCancelled();

    final googleAuth = await account.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) throw StateError('Không lấy được token từ Firebase.');
    return idToken;
  }

  /// Requires Apple Sign-In to be configured for this app (Apple Developer
  /// account: Services ID + key registered in Firebase Console → Authentication
  /// → Sign-in method → Apple). Until that's done this will throw.
  Future<String> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauthCredential = fb.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(oauthCredential);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) throw StateError('Không lấy được token từ Firebase.');
    return idToken;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await fb.FirebaseAuth.instance.signOut();
  }
}
