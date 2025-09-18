import 'package:upnp2/upnp.dart';

// NOTE: Open the example directory to see more elaborate examples
main() async {
  final disc = DeviceDiscoverer();
  await disc.start(ipv6: false);
  disc.quickDiscoverClients().listen((client) async {
    try {
      final dev = await client.getDevice();
      print('Found device: ${dev!.friendlyName}: ${dev.url}');
    } catch (e, stack) {
      print('ERROR: $e - ${client.location}');
      print(stack);
    }
  });
}
