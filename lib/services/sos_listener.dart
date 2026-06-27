class SOSListener {
  static void startListening() {
    // Local/in-app SOS notifications are intentionally disabled.
    // OneSignal is the single notification source for SOS alerts.
  }

  static Future<void> stopListening() async {}
}
