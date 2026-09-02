import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

class ShieldEncryptor {
  final RSAPublicKey _publicKey;

  ShieldEncryptor._(this._publicKey);

  /// Construct from a PEM string fetched from the backend.
  static ShieldEncryptor fromPem(String pem) =>
      ShieldEncryptor._(_parseSpkiPublicKey(pem));

  /// Wrap an AES secret key (base64-encoded string from the plugin) with the
  /// server's RSA public key. Returns the RSA-wrapped key as a base64 string.
  ///
  /// Used by [SafetyShieldAdapter] when the plugin emits an
  /// [EncryptedAudioEvent] with a raw AES key that needs server-side wrapping.
  String wrapAesKey(String aesSecretKeyBase64) {
    final aesKeyBytes = base64.decode(aesSecretKeyBase64);
    final oaep = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(_publicKey));
    final wrappedKey = oaep.process(Uint8List.fromList(aesKeyBytes));
    return base64.encode(wrappedKey);
  }

  /// Parse SPKI PEM → RSAPublicKey.
  static RSAPublicKey _parseSpkiPublicKey(String pem) {
    final der = base64.decode(pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s'), ''));
    final top =
        ASN1Parser(Uint8List.fromList(der)).nextObject() as ASN1Sequence;
    final bits = top.elements[1] as ASN1BitString;
    final keySeq = ASN1Parser(bits.contentBytes()).nextObject() as ASN1Sequence;
    return RSAPublicKey(
      (keySeq.elements[0] as ASN1Integer).valueAsBigInteger,
      (keySeq.elements[1] as ASN1Integer).valueAsBigInteger,
    );
  }
}
