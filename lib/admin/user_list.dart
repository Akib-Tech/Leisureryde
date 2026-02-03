// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
//
// class UsersListScreen extends StatefulWidget {
//   const UsersListScreen({super.key});
//
//   @override
//   State<UsersListScreen> createState() => _UsersListScreenState();
// }
//
// class _UsersListScreenState extends State<UsersListScreen> {
//   final DatabaseReference _usersRef =
//   FirebaseDatabase.instance.ref().child('users');
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Manage Users"),
//         centerTitle: true,
//         backgroundColor: Colors.blueAccent,
//       ),
//       body: StreamBuilder(
//         stream: _usersRef.onValue,
//         builder: (context, snapshot) {
//
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           if (!snapshot.hasData || snapshot.data == null) {
//             return const Center(child: Text("No users found."));
//           }
//
//           final event = snapshot.data as DatabaseEvent;
//
//           if (event.snapshot.value == null) {
//             return const Center(child: Text("No users found."));
//           }
//
//           final data = event.snapshot.value as Map<dynamic, dynamic>;
//
//           final List<Map<String, dynamic>> usersList = [];
//           data.forEach((key, value) {
//             final user = Map<String, dynamic>.from(value);
//
//
//             user['id'] = key;
//             usersList.add(user);
//           });
//
//
//           return ListView.builder(
//             itemCount: usersList.length,
//             itemBuilder: (context, index) {
//               final user = usersList[index];
//               final id = user['id'];
//               final first = user['firstname'] ?? '';
//               final last = user['lastname'] ?? '';
//               final name = (first.isEmpty && last.isEmpty) ? 'No Name' : '$first $last';
//               final email = user['email'] ?? 'No Email';
//               final status = user['blockStatus'] ?? '';
//               final profile = user['profileImage'] ??
//                   'https://cdn-icons-png.flaticon.com/512/149/149071.png';
//
//               return Card(
//                 margin:
//                 const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 elevation: 3,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//                 child: ListTile(
//                 /*  leading: CircleAvatar(
//                     backgroundImage: NetworkImage(profile),
//                     radius: 26,
//                   ),*/
//                   title: Text(name,
//                       style: const TextStyle(
//                           fontWeight: FontWeight.w600, fontSize: 16)),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(email),
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           const Text("Status: ",
//                               style: TextStyle(fontWeight: FontWeight.bold)),
//                           Text(
//                             status.toUpperCase(),
//                             style: TextStyle(
//                                 color: status == 'approved'
//                                     ? Colors.green
//                                     : status == 'blocked'
//                                     ? Colors.red
//                                     : Colors.orange),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   trailing: PopupMenuButton<String>(
//                     onSelected: (value) =>
//                         _updateUserStatus(id, value),
//                     itemBuilder: (context) => [
//                       const PopupMenuItem(
//                         value: 'approved',
//                         child: Text("Approve User"),
//                       ),
//                       const PopupMenuItem(
//                         value: 'blocked',
//                         child: Text("Block User"),
//                       ),
//                       const PopupMenuItem(
//                         value: 'pending',
//                         child: Text("Set Pending"),
//                       ),
//                     ],
//                     icon: const Icon(Icons.more_vert),
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   Future<void> _updateUserStatus(String userId, String newStatus) async {
//     try {
//       await _usersRef.child(userId).update({'blockStatus': newStatus});
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("User status updated to $newStatus"),
//           backgroundColor: Colors.indigo,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Error updating status: $e"),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//     }
//   }
// }
