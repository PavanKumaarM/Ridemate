import '../datasources/payment_datasource.dart';

class PaymentRepository {

  final PaymentDatasource datasource =
      PaymentDatasource();

  Future<void> makePayment(Map<String,dynamic> data){

    return datasource.createPayment(data);

  }

}