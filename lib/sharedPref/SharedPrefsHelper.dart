import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  // Keys

  final String _accessTokenKey = 'accessToken';
  final String _refreshTokenKey = 'refreshToken';
  final String _userID = 'userID';
  final String _officialID='officialID';
  final String _firstNameKey = 'firstName';
  final String _lastNameKey = 'lastName';
  final String _emailKey = 'email';
  final String _usernameKey = 'username';
  final String _savedImagePathKey = 'savedImagePath';
  final String _designationKey = 'designation';
  final String _departmentNameKey = 'departmentName';
  // Save data
  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }
  Future<void> saveOfficialID(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_officialID, token);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<void> saveUserDetails(int id,String firstName, String lastName, String email, String username,String designation, String departName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userID, id);
    await prefs.setString(_firstNameKey, firstName);
    await prefs.setString(_lastNameKey, lastName);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_designationKey, designation);
    await prefs.setString(_departmentNameKey,departName);
  }

  Future<Map<String, dynamic>> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final String? officialID= prefs.getString(_officialID);
    final String? fname = prefs.getString(_firstNameKey);
    final String? lname = prefs.getString(_lastNameKey);
    final String? designation = prefs.getString(_designationKey);
    final String? department = prefs.getString(_departmentNameKey);

    // Return the user details in a map
    return {
      'id': officialID,
      'fname': fname,
      'lname': lname,
      'designation': designation,
      'department': department,
    };
  }



  Future<void> saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedImagePathKey, path);
  }

  // Get data
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }
  // get Official ID
  Future<String?> getOfficialID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_officialID);
  }
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }
  // get ID
  Future<int?> getUserID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userID);
  }

  Future<String?> getSavedImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedImagePathKey);
  }

  // Remove data
  Future<void> removeAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
  }

  Future<void> removeRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }


  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
