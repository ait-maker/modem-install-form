// File generated based on Firebase project configuration
// Project: modem-install-2026

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration (from Firebase Console → Project settings → Web app)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkOhdun6rNIlg3oqtHdh8u_77dm7bgG50',
    appId: '1:1038229452599:web:e064f6c32f5a26511fdcb3',
    messagingSenderId: '1038229452599',
    projectId: 'modem-install-2026',
    storageBucket: 'modem-install-2026.firebasestorage.app',
  );

  // Android configuration (from google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQWDW0ufEqA1iOrh8i7n2b9vUIDymkBTU',
    appId: '1:381201607861:android:3c9c720cc8c21ed58862fc',
    messagingSenderId: '381201607861',
    projectId: 'modem-install-2026',
    storageBucket: 'modem-install-2026.firebasestorage.app',
  );
}
