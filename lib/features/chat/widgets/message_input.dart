import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/chat_provider.dart';

class MessageInput extends ConsumerStatefulWidget {

  final String tripId;
  final String senderId;

  const MessageInput({
    super.key,
    required this.tripId,
    required this.senderId,
  });

  @override
  ConsumerState<MessageInput> createState()
      => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {

  final TextEditingController controller =
      TextEditingController();

  void sendMessage() {

    final text = controller.text.trim();

    if(text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage({

      "trip_id": widget.tripId,
      "sender_id": widget.senderId,
      "message": text

    });

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      child: Row(

        children: [

          Expanded(

            child: TextField(

              controller: controller,

              decoration: const InputDecoration(
                hintText: "Type message...",
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          IconButton(

            icon: const Icon(Icons.send),

            onPressed: sendMessage,

          )

        ],
      ),
    );
  }
}