import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { vulnerableUser, emergencyContact, admin }

class UserSession {
  static UserRole? currentRole;

  static Future<void> loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      currentRole = null;
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      currentRole = null;
      return;
    }

    final roleString = (doc.data()?['role'] as String?)?.trim();

    if (roleString == null) {
      currentRole = null;
      return;
    }

    try {
      currentRole = UserRole.values.firstWhere((e) => e.name == roleString);
    } catch (_) {
      currentRole = null;
    }
  }

  static void setRoleFromString(String roleStr) {
    switch (roleStr) {
      case "vulnerableUser":
        currentRole = UserRole.vulnerableUser;
        break;
      case "emergencyContact":
        currentRole = UserRole.emergencyContact;
        break;
      case "admin":
        currentRole = UserRole.admin;
        break;
      default:
        currentRole = null;
    }
  }
}
