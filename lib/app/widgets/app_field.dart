import 'package:flutter/material.dart';

import '../tokens.dart';

/// Field with an uppercase mono label, a 50 px tall input row, and an
/// accent focus ring. Mirrors the design's password fields.
class AppField extends StatefulWidget {
  const AppField({
    super.key,
    this.label,
    required this.controller,
    this.hintText,
    this.obscure = false,
    this.prefixIcon,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.mono = false,
    this.validator,
  });

  final String? label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscure;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final bool mono;
  final FormFieldValidator<String>? validator;

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!.toUpperCase(), style: AppMono.label(context)),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? c.accentLine : c.border,
              width: focused ? 1.6 : 1,
            ),
            boxShadow: focused
                ? [BoxShadow(color: c.accentSoft, blurRadius: 0, spreadRadius: 3)]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 50,
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: 16, color: c.muted),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  obscuringCharacter: '•',
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  onFieldSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  validator: widget.validator,
                  cursorColor: c.accent,
                  style: widget.mono || widget.obscure
                      ? AppMono.of(
                          context,
                          size: 14.5,
                          color: c.fg,
                          letterSpacing: widget.obscure ? 4 : 0.5,
                        )
                      : TextStyle(color: c.fg, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    hintText: widget.hintText,
                    hintStyle: TextStyle(color: c.muted2, fontSize: 15),
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
      ],
    );
  }
}

/// 4-segment password strength meter beneath an [AppField].
class AppStrengthMeter extends StatelessWidget {
  const AppStrengthMeter({
    super.key,
    required this.score,
    this.leftLabel,
    this.rightLabel,
  });

  /// 0 (none) .. 4 (strong). Filled segments are tinted with the accent.
  final int score;
  final String? leftLabel;
  final String? rightLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < score ? c.accent : c.surface2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (leftLabel != null || rightLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (leftLabel != null)
                  Text(leftLabel!, style: AppMono.label(context))
                else
                  const SizedBox.shrink(),
                if (rightLabel != null)
                  Text(rightLabel!, style: AppMono.label(context))
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
