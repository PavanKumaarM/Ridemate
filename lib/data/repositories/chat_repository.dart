import '../datasources/chat_datasource.dart';

class ChatRepository {

  final ChatDatasource datasource = ChatDatasource();

  Future<void> sendMessage(Map<String,dynamic> data){

    return datasource.sendMessage(data);

  }
   Future<List<Map<String,dynamic>>> getMessages(String tripId) async {

    return await datasource.getMessages(tripId);

  }

}