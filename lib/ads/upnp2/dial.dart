import 'package:upnp2/dial.dart';

main() async {
  await for (DialScreen screen in DialScreen.find()) {
    final app = await screen.getCurrentApp();
    if (app != null) {
      print('Dial Screen ${screen.name} is running $app.');
    } else {
      print('Dial Screen ${screen.name} is idle.');
    }
  }
}
