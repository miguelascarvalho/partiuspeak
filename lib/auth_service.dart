import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Usuário logado atualmente
  User? get currentUser => _auth.currentUser;

  // Stream que atualiza sempre que o documento do usuário muda no Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>> get userStream {
    final user = currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  /// 🔒 Cria o documento do usuário no Firestore se ainda não existir
  Future<void> ensureUserDocumentExists() async {
    final user = currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set({
        'email': user.email,
        'role': 'free',
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'apple', // ou 'google', 'email', etc
      });
    }
  }

  /// 🔁 Atualiza algum campo do documento do usuário
  Future<void> updateUserField(String field, dynamic value) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({field: value});
  }

  /// 🚪 Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
