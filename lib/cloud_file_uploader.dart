/// This class [CloudFileUploader] for uploading, versioning, and managing JSON translation files
/// in a Google Cloud Storage bucket.
///
/// The [CloudFileUploader] handles:
/// - Authentication via a service account
/// - Version tracking of uploaded JSON files
/// - Uploading new translation files
/// - Making uploaded files public
/// - Deleting old files from both the cloud and the local directory

import 'dart:io';
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis_auth/auth_io.dart';

class CloudFileUploader {
  final String bucketName;
  // Removed folderPrefix usage as per your requirement to upload files directly to the bucket root
  final String? folderPrefix;

  static const _scopes = [storage.StorageApi.devstorageFullControlScope];
  final credentials = ServiceAccountCredentials.fromJson(
    File('service_account.json').readAsStringSync(),
  );

  late storage.StorageApi storageApi;
  late AutoRefreshingAuthClient authClient;
  late int oldJsonFilesVersion;

  CloudFileUploader._(this.bucketName, {this.folderPrefix});

  /// Async factory constructor to initialize once
  static Future<CloudFileUploader> create({
    required String bucketName,
    final String? folderPrefix
  }) async {
    final instance = CloudFileUploader._(bucketName, folderPrefix: folderPrefix);
    instance.authClient = await clientViaServiceAccount(instance.credentials, _scopes);
    instance.storageApi = storage.StorageApi(instance.authClient);
    instance.oldJsonFilesVersion = await instance.getOldJsonFilesVersion();
    return instance;
  }

  Future<int> getOldJsonFilesVersion() async {
    try {
      final objects = await storageApi.objects.list(bucketName);
      if (objects.items == null || objects.items!.isEmpty) {
        print("📂 No files exist inside bucket '$bucketName'.");
        return 0;
      }
      // Get highest version among all files in bucket
      int maxVersion = 0;
      for (var object in objects.items!) {
        try {
          final v = _extractVersionFromFilename(object.name!);
          if (v > maxVersion) maxVersion = v;
        } catch (_) {
          // ignore files without version suffix
        }
      }
      return maxVersion;
    } catch (e) {
      print("❌ Error in Old Version extracting: $e");
      return 0;
    }
  }

  Future<void> uploadNewJsonFiles() async {
    int nextVersion = oldJsonFilesVersion + 1;
    List<String> files = [
      "fr_FR_$nextVersion.json",
      "en_EN_$nextVersion.json",
      "es_ES_$nextVersion.json",
      "de_DE_$nextVersion.json",
      "pt_PT_$nextVersion.json",
      "nl_NL_$nextVersion.json",
      "it_IT_$nextVersion.json"
    ];

    if (!await _isInternetAvailable()) {
      print("❌ Error: No internet connection.");
      return;
    }

    try {
      await deleteAllFilesInBucket();
      print("\n🚀================== Step 4: Uploading new JSON files to Google Cloud Platform ================");
      for (final fileName in files) {
        await _uploadFileToGCS(fileName);
        await _makeObjectPublic(fileName);
      }

      deleteAllLocalJsonFiles();
    } catch (e) {
      print("❌ Error during upload: $e");
    }
  }

  Future<void> _uploadFileToGCS(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      print("❌ Local file not found: $filePath");
      return;
    }
    final media = storage.Media(file.openRead(), file.lengthSync());
    // Upload to bucket root: object name == filename only, no prefix
    final objectName = filePath;
    final object = storage.Object()..name = objectName;

    print("\n🚀  Uploading $filePath to $objectName...");
    try {
      await storageApi.objects.insert(object, bucketName, uploadMedia: media);
      print("✅ Uploaded: $objectName");
    } catch (e) {
      print("❌ Failed to upload $objectName: $e");
    }
  }

  static Future<bool> _isInternetAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteAllFilesInBucket() async {
    try {
      final objects = await storageApi.objects.list(bucketName);

      if (objects.items == null || objects.items!.isEmpty) {
        print("📂 No files to delete in the bucket '$bucketName'");
        return;
      }
      for (var object in objects.items!) {
        try {
          print("🗑️  Deleting old JSON File: ${object.name}");
          await storageApi.objects.delete(bucketName, object.name!);
        } catch (e) {
          // ignore files that don't match naming pattern
        }
      }

      print("✅ All Old JSON files are deleted inside the bucket : '$bucketName'");
    } catch (e) {
      print("❌ Error during deletion: $e");
    }
  }

  Future<void> _makeObjectPublic(String objectName) async {
    try {
      final policy = await storageApi.objectAccessControls.list(bucketName, objectName);

      final alreadyPublic = policy.items?.any(
            (entry) => entry.entity == 'allUsers' && entry.role == 'READER',
          ) ?? false;

      if (!alreadyPublic) {
        await storageApi.objectAccessControls.insert(
          storage.ObjectAccessControl()
            ..entity = 'allUsers'
            ..role = 'READER',
          bucketName,
          objectName,
        );
        print("🌍 The object '$objectName' is now public");
      } else {
        print("ℹ️ The object '$objectName' is already public");
      }
    } catch (e) {
      print("❌ Unable to make the object '$objectName' public: $e");
    }
  }

  static int _extractVersionFromFilename(String filename) {
    final regex = RegExp(r'_(\d+)\.json$');
    final match = regex.firstMatch(filename);
    if (match != null) {
      return int.parse(match.group(1)!);
    } else {
      throw FormatException("❌ No version number found in filename : $filename");
    }
  }

  void deleteAllLocalJsonFiles() {
    final currentDir = Directory.current;
    final regex = RegExp(r'_(\d+)\.json$');
    final jsonFiles = currentDir.listSync().whereType<File>().where((file) {
      final fileName = file.uri.pathSegments.last;
      return fileName.endsWith('.json') && regex.hasMatch(fileName);
    });
    for (final file in jsonFiles) {
      try {
        file.deleteSync();
        //print("🗑️ Deleted local Json file: ${file.path}");
      } catch (e) {
        print("❌ Failed to delete local Json file ${file.path}: $e");
      }
    }
  }

  /// Dispose client when done
  void dispose() {
    authClient.close();
  }
}