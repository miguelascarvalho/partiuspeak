import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:partiuspeak/home_page.dart';
import 'package:partiuspeak/pages/login_page.dart';
import 'package:partiuspeak/services/purchase_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ App Check (somente iOS/macOS, sem Android/Web)
    await FirebaseAppCheck.instance.activate();
  } catch (e) {
    debugPrint('⚠️ Erro ao inicializar Firebase/AppCheck: $e');
  }

  runApp(
    ChangeNotifierProvider<PurchaseService>(
      create: (_) => PurchaseService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PartiuSpeak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Montserrat',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomePage(); // Usuário logado
          }

          return const LoginPage(); // Usuário não logado
        },
      ),
    );
  }
}
