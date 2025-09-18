import 'package:upnp2/upnp.dart';

main(List<String> args) async {
  final client = DiscoveredClient.fake(args[0]);
  final device = await client.getDevice();
  print(device!.services);
  final service = await device.getService(args[1]);
  final result = await service!.invokeAction(args[2], {});
  print(result);
}
