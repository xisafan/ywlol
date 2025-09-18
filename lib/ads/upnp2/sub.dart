import 'dart:async';

import 'package:upnp2/src/utils.dart';
import 'package:upnp2/upnp.dart';

main() async {
  final discover = DeviceDiscoverer();
  await discover.start(ipv6: false);

  final List<Device> devices = await discover.getDevices();

  final sub = StateSubscriptionManager();
  await sub.init();

  for (Device device in devices) {
    for (ServiceDescription desc in device.services) {
      Service? service;

      try {
        service =
            await desc.getService(device).timeout(const Duration(seconds: 5));
      } catch (e) {
        print(e);
      }

      if (service != null) {
        try {
          sub.subscribeToService(service).listen((value) {
            print('${device.friendlyName} - ${service!.id}: $value');
          }, onError: (e, stack) {
            print(
                'Error while subscribing to ${service!.type} for ${device.friendlyName}: $e');
          });
        } catch (e) {
          print(e);
        }
      }
    }
  }

  Timer(const Duration(seconds: 60), () {
    print('Ended.');
    sub.close();

    Timer.run(() {
      UpnpCommon.httpClient.close();
    });
  });
}
