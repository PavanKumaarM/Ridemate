import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {

  final String message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {

    return Align(

      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(

        margin: const EdgeInsets.symmetric(
          vertical: 4,
        ),

        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 14,
        ),

        decoration: BoxDecoration(

          color: isMe
              ? Colors.blue
              : Colors.grey.shade300,

          borderRadius: BorderRadius.circular(12),

        ),

        child: Text(

          message,

          style: TextStyle(
            color: isMe ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}