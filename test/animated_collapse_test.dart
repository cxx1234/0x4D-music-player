import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/widgets/animated_collapse.dart';

void main() {
  testWidgets('visible=false 且 child 变为 SizedBox.shrink 后应塌陷到 0',
      (tester) async {
    // 初始：visible=true，child 有高度
    await tester.pumpWidget(
      Material(
        child: Column(
          children: [
            AnimatedCollapse(
              visible: true,
              child: Container(height: 40, color: Colors.red),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getSize(find.byType(AnimatedCollapse)).height;
    expect(before, 40, reason: '初始应显示内容');

    // 同一帧内 visible 翻 false 且 child 变成空（模拟 _buildScanResult 返回 shrink）
    await tester.pumpWidget(
      Material(
        child: Column(
          children: [
            const AnimatedCollapse(
              visible: false,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    // 淡出 200ms + 塌陷 250ms
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final after = tester.getSize(find.byType(AnimatedCollapse)).height;
    expect(after, 0, reason: '隐藏后应塌陷到 0');
  });

  testWidgets('visible=false 但 child 保持非空时也应塌陷到 0', (tester) async {
    await tester.pumpWidget(
      Material(
        child: Column(
          children: [
            AnimatedCollapse(
              visible: true,
              child: Container(height: 40, color: Colors.red),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 仅翻 visible，child 不变（两阶段设计：淡出期间内容仍在）
    await tester.pumpWidget(
      Material(
        child: Column(
          children: [
            AnimatedCollapse(
              visible: false,
              child: Container(height: 40, color: Colors.red),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final after = tester.getSize(find.byType(AnimatedCollapse)).height;
    expect(after, 0, reason: '隐藏后应塌陷到 0');
  });
}
