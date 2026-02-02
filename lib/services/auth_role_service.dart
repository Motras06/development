import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/tabs/admin/admin_home.dart';
import '/screens/tabs/client/client_home.dart';
import '/screens/tabs/leader/leader_home.dart';
import '/screens/tabs/worker/worker_home.dart';

class AuthRoleService {
  static Future<Widget> getHomeScreen() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox();

    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('is_admin')
          .eq('id', userId)
          .single();

      if (userData['is_admin'] == true) {
        return const AdminHomeScreen();
      }
    } catch (e) {}

    try {
      final rolesData = await Supabase.instance.client
          .from('project_participants')
          .select('role')
          .eq('user_id', userId);

      final roles = rolesData.map((e) => e['role'] as String).toSet();

      if (roles.contains('leader')) return const LeaderHome();
      if (roles.contains('worker')) return const WorkerHome();
      if (roles.contains('client')) return const ClientHome();
    } catch (e) {}

    return const ClientHome();
  }
}
