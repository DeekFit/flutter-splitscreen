import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen/split_screen.dart';
import 'native_channel_fixture.dart';

void main() {
  testWidgets(
    'web passes through even with iOS target platform',
    (tester) async {
      final native = NativeChannelFixture('split_screen/display_features');
      const data = MediaQueryData(size: Size(800, 600));
      late MediaQueryData observed;
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: SplitScreen(
            child: Builder(
              builder: (context) {
                observed = MediaQuery.of(context);
                return const TwoPane(
                  textDirection: TextDirection.ltr,
                  startPane: Text('First', textDirection: TextDirection.ltr),
                  endPane: Text('Second', textDirection: TextDirection.ltr),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(observed, same(data));
      expect(native.calls, isEmpty);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      native.dispose();
    },
    skip: !kIsWeb,
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
