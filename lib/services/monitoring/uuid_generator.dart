import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';

class UuidGenerator {
  // Singleton instance
  static final UuidGenerator _instance = UuidGenerator._internal();

  // Private constructor
  UuidGenerator._internal();

  // Factory constructor returns the same instance
  factory UuidGenerator() => _instance;


 String  generateUuid(String? method){
    try {
      final name = '$method-${DateTime.now().toIso8601String()}';
      final uuid = _generateUuidV5(name);
      return uuid;
    } catch(e){
     return "";
    }
  }
  /// Generates a UUID v5-like value based on namespace and name
  String _generateUuidV5(String name) {
    final namespaceBytes = utf8.encode(GlobalState().remoteUrl);
    final nameBytes = utf8.encode(name);
    final combined = Uint8List.fromList(namespaceBytes + nameBytes);
    final hash = _sha1(combined);

    hash[6] = (hash[6] & 0x0f) | 0x50; // Version 5
    hash[8] = (hash[8] & 0x3f) | 0x80; // Variant

    String bytesToHex(List<int> bytes, int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${bytesToHex(hash, 0, 4)}-'
        '${bytesToHex(hash, 4, 6)}-'
        '${bytesToHex(hash, 6, 8)}-'
        '${bytesToHex(hash, 8, 10)}-'
        '${bytesToHex(hash, 10, 16)}';
  }

  /// Minimal SHA-1 implementation in pure Dart
  List<int> _sha1(Uint8List message) {
    int rotl(int n, int bits) => ((n << bits) | (n >> (32 - bits))) & 0xffffffff;
    var h0 = 0x67452301;
    var h1 = 0xefcdab89;
    var h2 = 0x98badcfe;
    var h3 = 0x10325476;
    var h4 = 0xc3d2e1f0;

    var ml = message.lengthInBytes * 8;
    var newLength = message.length + 1;
    while ((newLength % 64) != 56) {
      newLength++;
    }
    var msg = Uint8List(newLength + 8);

    msg.setRange(0, message.length, message);
    msg[message.length] = 0x80;
    msg.buffer.asByteData().setUint32(msg.length - 4, ml, Endian.big);

    for (var i = 0; i < msg.length; i += 64) {
      var w = List<int>.filled(80, 0);
      for (var j = 0; j < 16; j++) {
        w[j] = msg.buffer.asByteData().getUint32(i + j * 4, Endian.big);
      }
      for (var j = 16; j < 80; j++) {
        w[j] = rotl(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);
      }

      var a = h0, b = h1, c = h2, d = h3, e = h4;

      for (var j = 0; j < 80; j++) {
        int f, k;
        if (j < 20) {
          f = (b & c) | ((~b) & d);
          k = 0x5a827999;
        } else if (j < 40) {
          f = b ^ c ^ d;
          k = 0x6ed9eba1;
        } else if (j < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8f1bbcdc;
        } else {
          f = b ^ c ^ d;
          k = 0xca62c1d6;
        }

        var temp = (rotl(a, 5) + f + e + k + w[j]) & 0xffffffff;
        e = d;
        d = c;
        c = rotl(b, 30);
        b = a;
        a = temp;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
    }

    final digest = ByteData(20);
    digest.setUint32(0, h0, Endian.big);
    digest.setUint32(4, h1, Endian.big);
    digest.setUint32(8, h2, Endian.big);
    digest.setUint32(12, h3, Endian.big);
    digest.setUint32(16, h4, Endian.big);
    return digest.buffer.asUint8List();
  }
}
