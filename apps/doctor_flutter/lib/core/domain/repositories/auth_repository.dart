abstract class AuthRepository {
  Future<bool> isAuthenticated();
  Future<void> login(String email, String password);
  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  });
  Future<void> otpLogin(String phone, String code);
  Future<void> sendOtp(String phone);
  Future<bool> verifyOtp(String phone, String code);
  Future<void> resetPassword(String phone, String code, String newPassword);
  Future<void> refresh();
  Future<void> logout();
  Future<String?> getToken();
  Future<String?> getRefreshToken();
  Future<String?> getUserId();
  Future<void> saveUserId(String userId);
}
