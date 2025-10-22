import 'package:flutter/material.dart';

final gold = const Color(0xffd4af37);
final black = Colors.black;

buildBottomSheet(BuildContext context, {required Function() movement}) {
  return Container(
    padding: const EdgeInsets.all(16),
    height: 220,
    decoration: const BoxDecoration(
      color: Colors.white, // White bottom sheet
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
      ],
    ),
    child: Column(
      children: [
        // Drag Handle
        Container(
          height: 4,
          width: 50,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.black12,
              child: Icon(Icons.directions_car, color: Colors.black),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text("Standard Ride",
                  style: TextStyle(color: Colors.black, fontSize: 16)),
            ),
            Text("\$12.50",
                style: TextStyle(
                    color: gold, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              movement;
            },
            child: const Text(
              "Confirm Ride",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  );
}