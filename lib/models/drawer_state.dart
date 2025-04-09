import 'package:flutter/material.dart';

/// Model to manage drawer state
class DrawerState {
  /// Global key for the drawer scaffold
  final GlobalKey<ScaffoldState> scaffoldKey;
  
  /// Whether the drawer is currently open
  bool _isDrawerOpen = false;
  
  /// Constructor
  DrawerState() : scaffoldKey = GlobalKey<ScaffoldState>();
  
  /// Returns whether the drawer is currently open
  bool get isDrawerOpen => _isDrawerOpen;
  
  /// Opens the drawer
  void openDrawer() {
    if (scaffoldKey.currentState != null && !_isDrawerOpen) {
      scaffoldKey.currentState!.openDrawer();
      _isDrawerOpen = true;
    }
  }
  
  /// Closes the drawer
  void closeDrawer() {
    if (scaffoldKey.currentState != null && _isDrawerOpen) {
      scaffoldKey.currentState!.openEndDrawer();
      _isDrawerOpen = false;
    }
  }
  
  /// Toggles the drawer state (opens if closed, closes if open)
  void toggleDrawer() {
    if (_isDrawerOpen) {
      closeDrawer();
    } else {
      openDrawer();
    }
  }
  
  /// Updates drawer state based on notification
  void handleDrawerCallback(bool isOpened) {
    _isDrawerOpen = isOpened;
  }
} 