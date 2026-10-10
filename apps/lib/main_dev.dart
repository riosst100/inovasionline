import 'main.dart';

Future<void> main() async {
  await bootstrap(envFile: '.env.dev', isDev: true);
}
