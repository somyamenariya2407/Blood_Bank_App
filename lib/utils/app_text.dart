import 'package:flutter/material.dart';

class AppText {
  static const supportedLocales = [
    Locale('en'),
    Locale('hi'),
  ];

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_language': 'App Language',
      'english': 'English',
      'hindi': 'Hindi',
      'preferences': 'Preferences',
      'settings_summary':
          'Control language, notifications and basic app information from one place.',
      'notifications': 'Notifications',
      'notifications_subtitle': 'Receive SOS and activity notifications',
      'change_language': 'Change Language',
      'change_language_subtitle': 'Choose the language used in the app',
      'about_app': 'About App',
      'version': 'Version',
      'privacy_policy': 'Privacy Policy',
      'privacy_policy_subtitle': 'View how your data is handled',
      'purpose': 'Purpose',
      'purpose_subtitle':
          'Emergency blood request, donor matching and hospital coordination',
      'privacy_policy_title': 'Privacy Policy',
      'privacy_policy_text_1':
          'Blood Bank App stores your profile, donation activity, request activity and selected settings to provide emergency matching and history features.',
      'privacy_policy_text_2':
          'Location is used only for nearby SOS and hospital discovery. Documents uploaded by hospitals are stored for verification purposes.',
      'privacy_policy_text_3':
          'You can disable notification preferences from this settings screen at any time.',
      'user_settings': 'User Settings',
      'hospital_settings': 'Hospital Settings',
      'hospital_profile': 'Hospital Profile',
      'my_profile': 'My Profile',
      'logout': 'Logout',
      'cancel': 'Cancel',
      'save': 'Save',
      'edit_profile': 'Edit Profile',
      'hospital_details': 'Hospital Details',
      'documents': 'Documents',
      'requests': 'Requests',
      'inventory': 'Inventory',
      'map': 'Map',
      'history': 'History',
      'status': 'Status',
      'home': 'Home',
      'sos': 'SOS',
      'profile': 'Profile',
      'my_requests': 'My Requests',
      'donate_nearby': 'Donate Nearby',
      'create_emergency_request': 'Create Emergency Request',
      'blood_group': 'Blood Group',
      'priority': 'Priority',
      'units_needed': 'Units Needed',
      'send_sos_alert': 'Send SOS Alert',
      'sending': 'Sending...',
      'navigate': 'Navigate',
      'call': 'Call',
      'donate_blood': 'Donate Blood',
      'waiting_for_approval': 'Waiting for approval',
      'awaiting_other_donor': 'Another donor is awaiting approval',
      'approved_to_donate': 'Approved to donate',
      'accept_donation': 'Accept',
      'reject_donation': 'Reject',
      'complete_donation': 'Complete Donation',
      'pending_donor': 'Pending donor',
      'approved_donor': 'Approved donor',
      'request_live':
          'Your active request is live and visible to nearby donors.',
      'no_active_requests_yet': 'No active requests yet.',
      'no_nearby_requests': 'No nearby requests right now.',
      'offer_sent': 'Donation request sent for approval.',
      'offer_accepted': 'Donation request accepted.',
      'offer_rejected': 'Donation request rejected.',
      'offer_waiting':
          'A donor is already waiting for approval on this request.',
      'own_request_donate_error': 'Cannot donate your own request',
      'donation_offer_title': 'Donation offer received',
      'donation_offer_message':
          '{donorName} wants to donate for your {bloodType} request.',
      'donation_accepted_title': 'Donation offer accepted',
      'donation_accepted_message':
          'Your donation offer for {bloodType} has been accepted.',
      'donation_rejected_title': 'Donation offer rejected',
      'donation_rejected_message':
          'Your donation offer for {bloodType} was not accepted.',
      'donation_completed_title': 'Donation completed',
      'donation_completed_message':
          '{donorName} completed the donation for your {bloodType} request.',
      'welcome_back': 'Welcome back',
      'available_to_donate': 'Available to Donate',
      'cannot_turn_on_yet':
          'You cannot turn donation on yet. Last donated on {date}.',
      'last_donated_on': 'Last donated on {date}',
      'recovery_mode_message':
          'You are in recovery mode after donating recently. You can still view requests, but donating stays disabled for now.',
      'visible_to_nearby':
          'You are visible to nearby hospitals and emergency requests.',
      'requests_only_mode':
          'You are currently in requests-only mode and will not be able to donate.',
      'blood': 'Blood',
      'donations': 'Donations',
      'lives': 'Lives',
      'nearby_blood_stock': 'Nearby Blood Stock',
      'confirm_sos': 'Confirm SOS',
      'requester': 'Requester',
      'type': 'Type',
      'phone': 'Phone',
      'address': 'Address',
      'hospital_request': 'Hospital request',
      'user_request': 'User request',
      'your_active_requests': 'Your active requests',
      'no_active_requests': 'No active requests',
      'no_compatible_requests': 'No compatible requests',
      'request_visible_cannot_donate':
          'Request is visible, but you cannot donate right now.',
      'eligible_to_respond': 'You are eligible to respond to this request.',
      'next_donation_active': 'Next donation active: {date}',
      'cooldown_block_message':
          'You cannot donate yet because of the 1 day cooldown. Next donation active: {date}.',
      'last_and_next_donation':
          'Last donated on {lastDate} | Next donation active: {nextDate}',
    },
    'hi': {
      'app_language': 'ऐप भाषा',
      'english': 'अंग्रेज़ी',
      'hindi': 'हिंदी',
      'preferences': 'पसंद',
      'settings_summary':
          'यहीं से भाषा, नोटिफिकेशन और ऐप की बेसिक जानकारी नियंत्रित करें।',
      'notifications': 'नोटिफिकेशन',
      'notifications_subtitle': 'SOS और गतिविधि नोटिफिकेशन प्राप्त करें',
      'change_language': 'भाषा बदलें',
      'change_language_subtitle': 'ऐप में उपयोग होने वाली भाषा चुनें',
      'about_app': 'ऐप के बारे में',
      'version': 'संस्करण',
      'privacy_policy': 'प्राइवेसी पॉलिसी',
      'privacy_policy_subtitle': 'जानें आपका डेटा कैसे उपयोग होता है',
      'purpose': 'उद्देश्य',
      'purpose_subtitle':
          'आपातकालीन रक्त अनुरोध, डोनर मिलान और अस्पताल समन्वय',
      'privacy_policy_title': 'प्राइवेसी पॉलिसी',
      'privacy_policy_text_1':
          'ब्लड बैंक ऐप आपका प्रोफ़ाइल, डोनेशन इतिहास, रिक्वेस्ट गतिविधि और चुनी गई सेटिंग्स सुरक्षित रखता है ताकि आपातकालीन मिलान और इतिहास सुविधाएँ दी जा सकें।',
      'privacy_policy_text_2':
          'लोकेशन का उपयोग केवल नज़दीकी SOS और अस्पताल खोज के लिए होता है। अस्पतालों के दस्तावेज़ सत्यापन के लिए सुरक्षित रखे जाते हैं।',
      'privacy_policy_text_3':
          'आप इस सेटिंग स्क्रीन से कभी भी नोटिफिकेशन बंद कर सकते हैं।',
      'user_settings': 'यूज़र सेटिंग्स',
      'hospital_settings': 'अस्पताल सेटिंग्स',
      'hospital_profile': 'अस्पताल प्रोफ़ाइल',
      'my_profile': 'मेरी प्रोफ़ाइल',
      'logout': 'लॉगआउट',
      'cancel': 'रद्द करें',
      'save': 'सेव करें',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'hospital_details': 'अस्पताल विवरण',
      'documents': 'दस्तावेज़',
      'requests': 'रिक्वेस्ट',
      'inventory': 'इन्वेंटरी',
      'map': 'मैप',
      'history': 'इतिहास',
      'status': 'स्टेटस',
      'home': 'होम',
      'sos': 'एसओएस',
      'profile': 'प्रोफ़ाइल',
      'my_requests': 'मेरी रिक्वेस्ट',
      'donate_nearby': 'नज़दीक डोनेट करें',
      'create_emergency_request': 'इमरजेंसी रिक्वेस्ट बनाएं',
      'blood_group': 'ब्लड ग्रुप',
      'priority': 'प्राथमिकता',
      'units_needed': 'ज़रूरी यूनिट्स',
      'send_sos_alert': 'SOS अलर्ट भेजें',
      'sending': 'भेजा जा रहा है...',
      'navigate': 'रास्ता देखें',
      'call': 'कॉल करें',
      'donate_blood': 'रक्त दान करें',
      'waiting_for_approval': 'स्वीकृति का इंतज़ार है',
      'awaiting_other_donor': 'किसी और डोनर की स्वीकृति लंबित है',
      'approved_to_donate': 'डोनेट करने की स्वीकृति मिल गई',
      'accept_donation': 'स्वीकार करें',
      'reject_donation': 'अस्वीकार करें',
      'complete_donation': 'डोनेशन पूरा करें',
      'pending_donor': 'लंबित डोनर',
      'approved_donor': 'स्वीकृत डोनर',
      'request_live':
          'आपकी सक्रिय रिक्वेस्ट लाइव है और नज़दीकी डोनर्स को दिखाई दे रही है।',
      'no_active_requests_yet': 'अभी कोई सक्रिय रिक्वेस्ट नहीं है।',
      'no_nearby_requests': 'अभी आसपास कोई रिक्वेस्ट नहीं है।',
      'offer_sent': 'डोनेशन रिक्वेस्ट स्वीकृति के लिए भेज दी गई है।',
      'offer_accepted': 'डोनेशन रिक्वेस्ट स्वीकार कर ली गई है।',
      'offer_rejected': 'डोनेशन रिक्वेस्ट अस्वीकार कर दी गई है।',
      'offer_waiting':
          'इस रिक्वेस्ट पर पहले से एक डोनर स्वीकृति का इंतज़ार कर रहा है।',
      'own_request_donate_error': 'आप अपनी ही रिक्वेस्ट पर डोनेट नहीं कर सकते',
      'donation_offer_title': 'डोनेशन ऑफर मिला',
      'donation_offer_message':
          '{donorName} आपकी {bloodType} रिक्वेस्ट के लिए डोनेट करना चाहता/चाहती है।',
      'donation_accepted_title': 'डोनेशन ऑफर स्वीकार हुआ',
      'donation_accepted_message':
          '{bloodType} के लिए आपका डोनेशन ऑफर स्वीकार कर लिया गया है।',
      'donation_rejected_title': 'डोनेशन ऑफर अस्वीकार हुआ',
      'donation_rejected_message':
          '{bloodType} के लिए आपका डोनेशन ऑफर स्वीकार नहीं किया गया।',
      'donation_completed_title': 'डोनेशन पूरा हुआ',
      'donation_completed_message':
          '{donorName} ने आपकी {bloodType} रिक्वेस्ट के लिए डोनेशन पूरा कर दिया है।',
      'welcome_back': 'वापसी पर स्वागत है',
      'available_to_donate': 'डोनेट करने के लिए उपलब्ध',
      'cannot_turn_on_yet':
          'आप अभी डोनेशन चालू नहीं कर सकते। पिछला डोनेशन {date} को हुआ था।',
      'last_donated_on': 'पिछला डोनेशन {date} को हुआ था',
      'recovery_mode_message':
          'आप हाल ही में डोनेट करने के बाद रिकवरी मोड में हैं। आप रिक्वेस्ट देख सकते हैं, लेकिन अभी डोनेट बंद रहेगा।',
      'visible_to_nearby':
          'आप नज़दीकी अस्पतालों और इमरजेंसी रिक्वेस्ट को दिखाई दे रहे हैं।',
      'requests_only_mode':
          'आप अभी केवल रिक्वेस्ट मोड में हैं और डोनेट नहीं कर पाएंगे।',
      'blood': 'ब्लड',
      'donations': 'डोनेशन',
      'lives': 'जिंदगियां',
      'nearby_blood_stock': 'नज़दीकी ब्लड स्टॉक',
      'confirm_sos': 'SOS की पुष्टि करें',
      'requester': 'अनुरोधकर्ता',
      'type': 'प्रकार',
      'phone': 'फोन',
      'address': 'पता',
      'hospital_request': 'अस्पताल की रिक्वेस्ट',
      'user_request': 'यूज़र की रिक्वेस्ट',
      'your_active_requests': 'आपकी सक्रिय रिक्वेस्ट',
      'no_active_requests': 'कोई सक्रिय रिक्वेस्ट नहीं है',
      'no_compatible_requests': 'कोई उपयुक्त रिक्वेस्ट नहीं है',
      'request_visible_cannot_donate':
          'रिक्वेस्ट दिख रही है, लेकिन आप अभी डोनेट नहीं कर सकते।',
      'eligible_to_respond': 'आप इस रिक्वेस्ट पर प्रतिक्रिया दे सकते हैं।',
      'next_donation_active': 'अगला डोनेशन सक्रिय: {date}',
      'cooldown_block_message':
          'आप अभी डोनेट नहीं कर सकते क्योंकि 1 दिन का कूलडाउन है। अगला डोनेशन सक्रिय: {date}.',
      'last_and_next_donation':
          'पिछला डोनेशन {lastDate} को हुआ | अगला डोनेशन सक्रिय: {nextDate}',
    },
  };

  static String text(
    BuildContext context,
    String key, {
    Map<String, String> params = const {},
  }) {
    final lang = Localizations.localeOf(context).languageCode;
    final base = _values[lang] ?? _values['en']!;
    var value = base[key] ?? _values['en']![key] ?? key;
    params.forEach((paramKey, paramValue) {
      value = value.replaceAll('{$paramKey}', paramValue);
    });
    return value;
  }
}
