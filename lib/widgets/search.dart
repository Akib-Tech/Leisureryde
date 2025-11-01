import 'package:flutter/material.dart';
final gold = const Color(0xFFd4af37);
final black = Colors.black;
buildSearchField(
    String hint, TextEditingController controller, IconData icon,
{required bool isPickup, required Function(String) location} ) {
  return Material(
    borderRadius: BorderRadius.circular(8),
    elevation: 2,
    child: TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      onSubmitted: (value) {
      },
      onChanged: (value){
        if(value.isNotEmpty){
          location;
        }

      },
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: gold),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      ),
    ),
  );
}
