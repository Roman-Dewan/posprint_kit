import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'posprint_kit_method_channel.dart';

abstract class PosprintKitPlatform extends PlatformInterface {
  /// Constructs a PosprintKitPlatform.
  PosprintKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static PosprintKitPlatform _instance = MethodChannelPosprintKit();

  /// The default instance of [PosprintKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelPosprintKit].
  static PosprintKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PosprintKitPlatform] when
  /// they register themselves.
  static set instance(PosprintKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
