part of '../main.dart';

final nightMode = ValueNotifier<bool>(false);

Color get green =>
    nightMode.value ? const Color(0xFF52CE64) : const Color(0xFF32B43A);
Color get darkGreen =>
    nightMode.value ? const Color(0xFF7BE18A) : const Color(0xFF248A2A);
Color get softGreen =>
    nightMode.value ? const Color(0xFF203629) : const Color(0xFFE9F8EB);
Color get ink =>
    nightMode.value ? const Color(0xFFF2F7F2) : const Color(0xFF172019);
Color get muted =>
    nightMode.value ? const Color(0xFFB2C0B5) : const Color(0xFF9299AE);
Color get canvas =>
    nightMode.value ? const Color(0xFF101713) : const Color(0xFFFAFCF9);
Color get surface => nightMode.value ? const Color(0xFF1B271E) : Colors.white;
Color get line =>
    nightMode.value ? const Color(0xFF314536) : const Color(0xFFEDF0ED);
Color get red =>
    nightMode.value ? const Color(0xFFFF8580) : const Color(0xFFEB5757);
Color get rose =>
    nightMode.value ? const Color(0xFF3C282B) : const Color(0xFFFFF0EF);
Color get gold =>
    nightMode.value ? const Color(0xFF3D3524) : const Color(0xFFFFF7DD);
Color get lavender =>
    nightMode.value ? const Color(0xFF322D45) : const Color(0xFFF1EFFF);
Color get milkTone =>
    nightMode.value ? const Color(0xFF283746) : const Color(0xFFEAF2FA);
Color get attentionStart =>
    nightMode.value ? const Color(0xFF223A29) : const Color(0xFFEFFBEF);
Color get attentionEnd =>
    nightMode.value ? const Color(0xFF1B2C21) : const Color(0xFFF9FFF8);

BoxShadow get shadow => BoxShadow(
  color: nightMode.value ? const Color(0x55000000) : const Color(0x12203E25),
  blurRadius: 28,
  offset: const Offset(0, 8),
);

TextStyle type(double size, {bool bold = false, Color? color}) => TextStyle(
  fontSize: size,
  color: color ?? ink,
  fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
);
