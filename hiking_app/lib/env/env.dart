import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'MAPBOX_KEY', obfuscate: true)
  static final String mapboxKey = _Env.mapboxKey;
}
