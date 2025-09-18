import 'dart:io';

import 'package:upnp2/router.dart';

main() async {
  await for (var router in Router.findAll()) {
    final address = await router.getExternalIpAddress();
    print('Router ${Uri.parse(router.device!.url!).host}:');
    print('  External IP Address: $address');
    final totalBytesSent = await router.getTotalBytesSent();
    print('  Total Bytes Sent: $totalBytesSent bytes');
    final totalBytesReceived = await router.getTotalBytesReceived();
    print('  Total Bytes Received: $totalBytesReceived bytes');
    final totalPacketsSent = await router.getTotalPacketsSent();
    print('  Total Packets Sent: $totalPacketsSent bytes');
    final totalPacketsReceived = await router.getTotalPacketsReceived();
    print('  Total Packets Received: $totalPacketsReceived bytes');
  }

  exit(0);
}
