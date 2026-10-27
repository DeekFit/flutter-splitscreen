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
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(observed, same(data));
      expect(native.calls, isEmpty);
      native.dispose();
    },
    skip: !kIsWeb,
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
