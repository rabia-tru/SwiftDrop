import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('http://localhost:3000/api/business/list'));
  print('Status code: ${res.statusCode}');
  final List decoded = jsonDecode(res.body);
  print('Total businesses from API: ${decoded.length}');

  // Find business 'pizza'
  final pizzaBiz = decoded.firstWhere((b) => b['name'] == 'pizza', orElse: () => null);
  if (pizzaBiz == null) {
    print('ERROR: pizza business NOT FOUND in /business/list!');
    return;
  }
  print('Found pizza business:');
  print('ID: ${pizzaBiz['id']}');
  print('Category: ${pizzaBiz['category']}');
  print('Menu items in list response: ${(pizzaBiz['menuItems'] as List).length}');
  for (final item in pizzaBiz['menuItems']) {
    print(' - ${item['name']} (cat: ${item['category']}, price: ${item['price']}, img: ${item['imageUrl']})');
  }

  // Now test public menu endpoint:
  final menuRes = await http.get(Uri.parse('http://localhost:3000/api/business/${pizzaBiz['id']}/menu'));
  print('Menu endpoint status: ${menuRes.statusCode}');
  final List menuDecoded = jsonDecode(menuRes.body);
  print('Menu endpoint returned ${menuDecoded.length} items');
}
