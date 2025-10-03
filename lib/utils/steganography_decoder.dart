import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

/// 资源解析器
class SteganographyDecoder {
  static const String _s = "OVO_START_";
  static const String _e = "_OVO_END";

  /// 从资源中解析
  static Future<Map<String, dynamic>?> decodeFromAsset(String imagePath) async {
    try {
      final ByteData data = await rootBundle.load(imagePath);
      final Uint8List bytes = data.buffer.asUint8List();

      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final binaryMessage = _extractBinaryData(image);
      if (binaryMessage.isEmpty) return null;

      final message = _binaryToString(binaryMessage);
      if (message.isEmpty) return null;

      final startIndex = message.indexOf(_s);
      final endIndex = message.indexOf(_e);

      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        return null;
      }

      final content = message.substring(startIndex + _s.length, endIndex);
      final parts = content.split('|');
      if (parts.length < 3) return null;

      final expectedLength = int.tryParse(parts[0]);
      final expectedChecksum = parts[1];
      final jsonData = parts.sublist(2).join('|');

      if (expectedLength == null) return null;

      final actualChecksum = _calculateChecksum(jsonData);
      if (actualChecksum != expectedChecksum) return null;

      try {
        final config = json.decode(jsonData) as Map<String, dynamic>;
        return config;
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static String _extractBinaryData(img.Image image) {
    final binary = StringBuffer();
    int bitCount = 0;
    const maxBits = 1000000;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (bitCount >= maxBits) break;
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        binary.write((r & 1).toString());
        binary.write((g & 1).toString());
        binary.write((b & 1).toString());
        bitCount += 3;
      }
      if (bitCount >= maxBits) break;
    }
    return binary.toString();
  }

  static String _binaryToString(String binary) {
    final buffer = StringBuffer();
    for (int i = 0; i < binary.length - 7; i += 8) {
      final byte = binary.substring(i, i + 8);
      final charCode = int.parse(byte, radix: 2);
      if (charCode >= 32 && charCode <= 126 || 
          charCode == 10 || charCode == 13 || charCode == 9) {
        buffer.writeCharCode(charCode);
      } else if (charCode == 0) {
        break;
      }
    }
    return buffer.toString();
  }

  static String _calculateChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}

/// 配置管理器
class StegConfigManager {
  static Map<String, dynamic>? _c;

  static Future<Map<String, dynamic>?> loadConfig({
    String imagePath = 'assets/image/home.png',
    bool useCache = true,
  }) async {
    if (useCache && _c != null) return _c;
    _c = await SteganographyDecoder.decodeFromAsset(imagePath);
    return _c;
  }

  static String? getDomainConfigUrl() => _c?['domain_config_url'] as String?;
  static String? getDefaultApiDomain() => _c?['default_api_domain'] as String?;
  static String? getEncryptKey() => _c?['encrypt_key'] as String?;
  static Map<String, dynamic>? getUmengConfig() => _c?['umeng'] as Map<String, dynamic>?;
  static Map<String, dynamic>? getAdConfig() => _c?['ad'] as Map<String, dynamic>?;
  
  static List<String>? getBackupDomains() {
    final domains = _c?['backup_domains'];
    if (domains is List) return domains.cast<String>();
    return null;
  }

  static Map<String, dynamic>? getFeatures() => _c?['features'] as Map<String, dynamic>?;
  static void clearCache() => _c = null;
}

