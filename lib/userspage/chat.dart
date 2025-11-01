import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/methods/message.dart';
import 'package:leisureryde/widgets/requestlist.dart';
import 'package:random_string/random_string.dart';

import '../methods/sharedpref.dart' show SharedPref;

class ChatScreen extends StatefulWidget {

  final String receiverId;
  final String receiverName;
  const ChatScreen({
    super.key,
    required this.receiverName,
    required this.receiverId,
  });
  /*final String chatId; // Unique chat ID (e.g. rideId or driver+rider)
  final String receiverName;
  final String receiverId;

  const ChatScreen({
    Key? key,
    required this.receiverId,
  }) : super(key: key);

  */
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  void sendMessage() async {
    final userId = await SharedPref().getUserId();
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    String id = randomAlphaNumeric(10);
  final DatabaseReference db=   cMethods.dBase.ref().child('messages');
    await db.child(id).set({
      'id' : id,
      'receiverId': widget.receiverId,
      'text': message,
      'senderId': userId,
      //'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    const black = Colors.black;
    const darkGray = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: black,
      appBar: AppBar(
        backgroundColor: black,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: gold,
              child: Icon(Icons.person, color: black),
            ),
            const SizedBox(width: 10),
            Text(
              widget.receiverName,
              style: const TextStyle(
                color: gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: StreamBuilder<List<Map<String,dynamic>?>>(
              stream: fetchMessage(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index] as Map<String, dynamic>;
                    final isMe =
                        data['senderId'] == SharedPref().getUserId();

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                        padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? gold : darkGray,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                            Radius.circular(isMe ? 18 : 0), // Tail shape
                            bottomRight:
                            Radius.circular(isMe ? 0 : 18), // Tail shape
                          ),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? black : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Bar
          SafeArea(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              color: darkGray,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.black54,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
