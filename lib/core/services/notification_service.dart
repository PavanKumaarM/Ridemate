import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  Future<void> initialize() async {

    await _messaging.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {

      print("Notification received");

    });

  }

}