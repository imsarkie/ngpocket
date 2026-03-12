import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ngpocket/main.dart';

void main() {
  testWidgets('app shell renders bottom nav icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NgPocketApp()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });
}
