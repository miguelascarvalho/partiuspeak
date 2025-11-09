// File simplified for iOS/macOS only
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return apple;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for iOS/macOS in this build.',
        );
    }
  }

  static const FirebaseOptions apple = FirebaseOptions(
    apiKey: 'AIzaSyB-Om2WxL-bsuTRfOBdVg9J5RJfh0Z8-d8',
    appId: '1:345824825969:ios:632e8d05ad8083ad7501d0',
    messagingSenderId: '345824825969',
    projectId: 'partiu-speak',
    storageBucket: 'partiu-speak.appspot.com', // ✅
    androidClientId:
    '345824825969-atabjrjj5gmlvanehspuk2l9sjndf0mu.apps.googleusercontent.com',
    iosClientId:
    '345824825969-rokgs01tkk2p9cqhethr8b80obca84pe.apps.googleusercontent.com',
    iosBundleId: 'br.com.partiuspeak.app',
  );
}
