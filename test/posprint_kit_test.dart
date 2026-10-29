import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';
import 'package:posprint_kit/posprint_kit_platform_interface.dart';
import 'package:posprint_kit/posprint_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPosprintKitPlatform
    with MockPlatformInterfaceMixin
    implements PosprintKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PosprintKitPlatform initialPlatform = PosprintKitPlatform.instance;

  test('$MethodChannelPosprintKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPosprintKit>());
  });

  test('getPlatformVersion', () async {
    // OLD: PosprintKit posprintKitPlugin = PosprintKit();
    final PosprintKit posprintKitPlugin = PosprintKit();
    // OLD: MockPosprintKitPlatform fakePlatform = MockPosprintKitPlatform();
    final MockPosprintKitPlatform fakePlatform = MockPosprintKitPlatform();
    PosprintKitPlatform.instance = fakePlatform;

    expect(await posprintKitPlugin.getPlatformVersion(), '42');
  });
}
