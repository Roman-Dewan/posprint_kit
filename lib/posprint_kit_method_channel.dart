import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'posprint_kit_platform_interface.dart';

/// An implementation of [PosprintKitPlatform] that uses method channels.
class MethodChannelPosprintKit extends PosprintKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('posprint_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
