class Validators {

  static String? validatePhone(String? value) {

    if (value == null || value.isEmpty) {
      return "Phone number required";
    }

    if (value.length < 10) {
      return "Invalid phone number";
    }

    return null;
  }

  static String? validateRequired(String? value) {

    if (value == null || value.isEmpty) {
      return "Field required";
    }

    return null;
  }

}