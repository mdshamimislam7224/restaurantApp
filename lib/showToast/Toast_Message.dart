import 'dart:ui';

import 'package:fluttertoast/fluttertoast.dart';

class Toast_Message
{
  void showToast(String message,Color bgColor,Color textColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 2,
      backgroundColor: bgColor,
      textColor: textColor,
      fontSize: 16.0,
    );
  }
}