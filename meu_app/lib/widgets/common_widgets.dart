part of '../main.dart';

Widget scroll(List<Widget> children) => ListView(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
  children: children,
);

Widget topbar(String title, {VoidCallback? back, Widget? action}) => SizedBox(
  height: 50,
  child: Row(
    children: [
      SizedBox(
        width: 44,
        child: back == null
            ? null
            : IconButton(
                onPressed: back,
                icon: const Icon(Icons.arrow_back_ios_new, size: 19),
              ),
      ),
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: type(18, bold: true),
        ),
      ),
      SizedBox(width: 44, child: action),
    ],
  ),
);

Widget subtitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: Text(
    text,
    textAlign: TextAlign.center,
    style: type(13, color: muted),
  ),
);

Widget panel(
  Widget child, {
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  bool custom = false,
}) => Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    boxShadow: [shadow],
  ),
  child: Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: custom ? EdgeInsets.zero : padding, child: child),
  ),
);
Widget badge(
  IconData icon,
  Color background,
  Color foreground, {
  double size = 35,
}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(size * .31),
  ),
  child: Icon(icon, size: size * .56, color: foreground),
);

Widget primary(
  String text,
  VoidCallback onTap, {
  IconData? icon,
  IconData? trailing,
}) => SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 21), const SizedBox(width: 8)],
        Text(text, style: type(13, bold: true, color: Colors.white)),
        if (trailing != null) ...[const Spacer(), Icon(trailing)],
      ],
    ),
  ),
);

Widget smallButton(String text, VoidCallback onTap) => SizedBox(
  height: 36,
  child: ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: Text(text, style: type(12, bold: true, color: Colors.white)),
  ),
);

InputDecoration input(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: type(13, color: muted),
  filled: true,
  fillColor: surface,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: green, width: 1.5),
  ),
);

Widget field(
  String title,
  String hint,
  TextEditingController controller, {
  bool hidden = false,
  TextInputType? keyboard,
  VoidCallback? onToggleVisibility,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(title, style: type(12, bold: true)),
    const SizedBox(height: 7),
    TextField(
      controller: controller,
      obscureText: hidden,
      keyboardType: keyboard,
      enableSuggestions: onToggleVisibility == null,
      autocorrect: onToggleVisibility == null,
      decoration: input(hint).copyWith(
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                onPressed: onToggleVisibility,
                tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: muted,
                ),
              ),
      ),
    ),
  ],
);

class EntryPage extends StatefulWidget {
  const EntryPage({super.key, required this.title, required this.builder});

  final String title;
  final List<Widget> Function(BuildContext, void Function(VoidCallback))
  builder;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    body: SafeArea(
      child: scroll([
        topbar(widget.title, back: () => Navigator.pop(context)),
        ...widget.builder(context, (fn) => setState(fn)),
      ]),
    ),
  );
}
