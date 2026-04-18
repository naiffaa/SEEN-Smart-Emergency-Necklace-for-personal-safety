import 'package:flutter/material.dart';
import '../session/user_session.dart';

import '../../features/dashboard/vulnerable_user/vu_shell.dart';
import '../../features/dashboard/admin/admin_shell.dart';
import '../../features/dashboard/emergency_contact/ec_shell.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    await UserSession.loadUserRole();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = UserSession.currentRole;

    switch (role) {
      case UserRole.vulnerableUser:
        return const VUShell();

      case UserRole.emergencyContact:
        return const ECShell();

      case UserRole.admin:
        return const AdminShell();

      default:
        return const Scaffold(body: Center(child: Text("No role selected")));
    }
  }
}
