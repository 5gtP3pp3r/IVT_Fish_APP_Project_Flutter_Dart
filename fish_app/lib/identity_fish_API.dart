import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

Future<int> getImageByteSize(String picturePath) async {
  final file = File(picturePath);
  return await file.length();
}

Future<String> getMd5ChecksumBase64(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  final digest = md5.convert(bytes);
  return base64Encode(digest.bytes);
}
