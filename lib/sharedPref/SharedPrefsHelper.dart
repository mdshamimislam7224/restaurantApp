import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SharedPrefsHelper {


  // Staff Login Keys
  final String _staffIdKey = 'staff_id';
  final String _staffNameKey = 'staff_name';
  final String _staffJoiningDateKey = 'joiningdate';
  final String _staffPositionKey = 'staff_position';
  final String _staffStatusKey = 'status';
  final String _staffUserRoleKey = 'userrole';
  final String _loginTimeKey = 'login_time';
  final String _userDataKey = 'user_data';

  // ✅ Save Staff Login Data
  Future<void> saveStaffLoginData(Map<String, dynamic> staffInfo) async {
    final prefs = await SharedPreferences.getInstance();

    // 🧩 Format joining date if available
    String formattedJoiningDate = '';
    if (staffInfo['joiningdate'] != null && staffInfo['joiningdate'].toString().isNotEmpty) {
      try {
        DateTime utcDate = DateTime.parse(staffInfo['joiningdate']);
        DateTime localDate = utcDate.toLocal();
        formattedJoiningDate = DateFormat('yyyy-MM-dd').format(localDate);
      } catch (e) {
        print('⚠️ Invalid joiningdate format: $e');
      }
    }

    // Save the required fields
    await prefs.setString(_staffIdKey, staffInfo['staff_id']?.toString() ?? '');
    await prefs.setString(_staffNameKey, staffInfo['staff_name']?.toString() ?? '');
    await prefs.setString(_staffPositionKey, staffInfo['staff_position']?.toString() ?? '');
    await prefs.setString(_staffStatusKey, staffInfo['status']?.toString() ?? '');
    await prefs.setString(_staffUserRoleKey, staffInfo['userrole']?.toString() ?? '');
    await prefs.setString(_staffJoiningDateKey, formattedJoiningDate);

    // Save login timestamp
    await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());

    // Save all user data as JSON string for future use
    await prefs.setString(_userDataKey, jsonEncode(staffInfo));

    print('✅ Staff login data saved to SharedPreferences');
    print('🗓️ Formatted joining date: $formattedJoiningDate');
  }

  // ✅ Get Staff Login Data
  Future<Map<String, String>> getStaffLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'staff_id': prefs.getString(_staffIdKey) ?? '',
      'staff_name': prefs.getString(_staffNameKey) ?? '',
      'staff_position': prefs.getString(_staffPositionKey) ?? '',
      'status': prefs.getString(_staffStatusKey) ?? '',
      'userrole': prefs.getString(_staffUserRoleKey) ?? '',
      'joiningdate': prefs.getString(_staffJoiningDateKey) ?? '',
    };
  }

  // ✅ Get Complete Staff Data (from JSON)
  Future<Map<String, dynamic>?> getCompleteStaffData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userDataJson = prefs.getString(_userDataKey);
    if (userDataJson != null && userDataJson.isNotEmpty) {
      try {
        return jsonDecode(userDataJson);
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }


  // ✅ Get Staff User Role
  Future<String> getStaffUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_staffUserRoleKey) ?? '';
  }

  // ✅ Get Login Time
  Future<DateTime?> getLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? loginTimeStr = prefs.getString(_loginTimeKey);
    if (loginTimeStr != null && loginTimeStr.isNotEmpty) {
      try {
        return DateTime.parse(loginTimeStr);
      } catch (e) {
        print('Error parsing login time: $e');
      }
    }
    return null;
  }
  // get Official ID
  Future<String?> getOfficialID() async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString(_staffIdKey);
    return prefs.getString(_staffIdKey);
  }

  // ✅ Remove Staff Login Data
  Future<void> removeStaffLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_staffIdKey);
    await prefs.remove(_staffNameKey);
    await prefs.remove(_staffPositionKey);
    await prefs.remove(_staffStatusKey);
    await prefs.remove(_staffUserRoleKey);
    await prefs.remove(_loginTimeKey);
    await prefs.remove(_userDataKey);
  }
  Future<bool> isStaffLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString(_staffIdKey);
    return staffId != null && staffId.isNotEmpty;
  }
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ✅ Clear only staff data (keep other app data)
  Future<void> clearStaffDataOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await removeStaffLoginData();
  }
}