import 'package:flutter/material.dart';

/// 可点击文本链接：hover 时文本变主题色并加淡色底，点击触发 [onTap]。
///
/// 墨迹限定在文本范围内（透明 [Material]），适合放在播放信息等非列表场景。
class TextLink extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final VoidCallback onTap;

  const TextLink({
    super.key,
    required this.text,
    required this.style,
    required this.onTap,
  });

  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = widget.style ?? theme.textTheme.bodyLarge;
    final color = _hovered
        ? theme.colorScheme.primary
        : base?.color ?? theme.colorScheme.onSurfaceVariant;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        onHover: (v) => setState(() => _hovered = v),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
