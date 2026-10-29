
import 'posprint_kit_platform_interface.dart';

class PosprintKit {
  Future<String?> getPlatformVersion() {
    return PosprintKitPlatform.instance.getPlatformVersion();
  }
}
