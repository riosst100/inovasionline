import 'main.dart';

Future<void> main() async {
  await bootstrap(envFile: '.env.prod', isDev: false);
}
