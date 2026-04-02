import '../datasources/supabase_auth_datasource.dart';

class AuthRepository {

  final SupabaseAuthDatasource datasource =
      SupabaseAuthDatasource();

  Future<void> login(String phone) {

    return datasource.signInWithPhone(phone);

  }

}