import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

Future<int> getImageByteSize(String picturePath) async {
  final file = File(picturePath);
  return await file.length();
}

Future<String> getMd5ChecksumBase64(String picturePath) async {
  final file = File(picturePath);
  final bytes = await file.readAsBytes();
  final digest = md5.convert(bytes);
  return base64Encode(digest.bytes);
}

Future<String> getAccessToken() async {

}



Future<String> identifyFish(String picturePath) async {
  final String filname = picturePath.split("/").last;
  final String mime = "image/jpeg";
  final int byteSize = await getImageByteSize(picturePath);
  final String checksum = await getMd5ChecksumBase64(picturePath);



}
