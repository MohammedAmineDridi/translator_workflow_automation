/// This class [RemoteConfigCloudFunction] is responsible for calling a Cloud Function
/// that automatically increments the `lang_version` variable in Firebase Remote Config
/// after uploading new translation JSON files with a new version to Google Cloud Storage (GCS).

import 'package:http/http.dart' as http;

class RemoteConfigCloudFunction {
  final bool callStatus;
  RemoteConfigCloudFunction({required this.callStatus});
  Future<void> notifyLangVersionUpdate({required String region, required String projectId, required String cloudFunctionName}) async {
    if (callStatus) {
      final uri = Uri.parse('https://$region-$projectId.cloudfunctions.net/$cloudFunctionName');
      try {
        final response = await http.post(uri);
        if (response.statusCode == 200) {
          print("✅ Remote config language version incremented successfully.");
        } else {
          print("❌ Failed to increment remote config version: ${response.statusCode} ${response.body}");
        }
      } catch (e) {
        print("❌ Error calling remote config updater API: $e");
      }
    }
  } 
}