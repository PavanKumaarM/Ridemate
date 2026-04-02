// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../providers/chat_provider.dart';
// import '../widgets/message_bubble.dart';
// import '../widgets/message_input.dart';

// class ChatScreen extends ConsumerWidget {

//   final String tripId;
//   final String currentUserId;

//   const ChatScreen({
//     super.key,
//     required this.tripId,
//     required this.currentUserId
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {

//     final messagesStream = ref.watch(chatRepositoryProvider).getMessages(tripId);

//     return Scaffold(

//       appBar: AppBar(
//         title: const Text("Trip Chat"),
//       ),

//       body: Column(

//         children: [

//           Expanded(

//             child: messagesStream.when(

//               data: (messages){

//                 return ListView.builder(

//                   padding: const EdgeInsets.all(12),

//                   itemCount: messages.length,

//                   itemBuilder: (context,index){

//                     final message = messages[index];

//                     final isMe =
//                         message.senderId == currentUserId;

//                     return MessageBubble(
//                       message: message.message,
//                       isMe: isMe,
//                     );
//                   },
//                 );
//               },

//               loading: ()=> const Center(
//                 child: CircularProgressIndicator(),
//               ),

//               error: (e,_)=> Center(
//                 child: Text(e.toString()),
//               ),
//             ),

//           ),

//           MessageInput(
//             tripId: tripId,
//             senderId: currentUserId,
//           )

//         ],
//       ),
//     );
//   }
// }