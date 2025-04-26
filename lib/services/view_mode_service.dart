import 'package:shared_preferences/shared_preferences.dart';

class ViewModeService {
  static const String _isGridViewKey = 'isGridView';
  static final ViewModeService instance = ViewModeService._internal();
  
  ViewModeService._internal();

  Future<bool> getIsGridView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGridViewKey) ?? true;
  }

  Future<void> setIsGridView(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGridViewKey, value);
  }
}
