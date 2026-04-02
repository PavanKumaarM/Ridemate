import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {

  late Razorpay _razorpay;

  void initialize() {

    _razorpay = Razorpay();

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handleSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handleError,
    );

  }

  void startPayment(int amount) {

    var options = {

      'key': 'RAZORPAY_KEY',
      'amount': amount * 100,
      'name': 'Ride Companion',

    };

    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) {

    print("Payment success");

  }

  void _handleError(PaymentFailureResponse response) {

    print("Payment failed");

  }

}