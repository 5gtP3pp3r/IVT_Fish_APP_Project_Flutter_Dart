import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<int> getImageByteSize(String picturePath) async {
  final file = File(picturePath);
  return await file.length();
}


