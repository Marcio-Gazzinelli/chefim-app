part of '../main.dart';

class PasswordService {
  const PasswordService._();

  static String hash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool verify(String password, String passwordHash) {
    try {
      return BCrypt.checkpw(password, passwordHash);
    } catch (_) {
      return false;
    }
  }
}
