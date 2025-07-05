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
  final String? folderPrefix;

  static const _scopes = [storage.StorageApi.devstorageFullControlScope];
  final credentials = ServiceAccountCredentials.fromJson(
    File('service_account.json').readAsStringSync(),
  );

  late storage.StorageApi storageApi;
  late AutoRefreshingAuthClient authClient;
  late int oldJsonFilesVersion;

  CloudFileUploader._(this.bucketName, {this.folderPrefix});

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

  String get _normalizedPrefix {
    if (folderPrefix == null || folderPrefix!.isEmpty) return '';
    return folderPrefix!.endsWith('/') ? folderPrefix! : '${folderPrefix!}/';
  }

  Future<int> getOldJsonFilesVersion() async {
    try {
      final objects = await storageApi.objects.list(
        bucketName,
        prefix: folderPrefix ?? '',
      );

      if (objects.items == null || objects.items!.isEmpty) {
        print("📂 No files exist inside bucket : '$bucketName/${(folderPrefix ?? '')}'.");
        return 0;
      }
      int maxVersion = 0;
      for (var object in objects.items!) {
        try {
          final v = _extractVersionFromFilename(object.name!);
          if (v > maxVersion) maxVersion = v;
        } catch (_) {}
      }
      return maxVersion;
    } catch (e) {
      print("❌ Error in Old Version extracting: $e");
      return 0;
    }
  }

  Future<void> uploadNewJsonFiles() async {
    const supportedLanguages = ['fr_FR', 'en_EN', 'es_ES', 'de_DE', 'pt_PT', 'nl_NL', 'it_IT'];
    int nextVersion = oldJsonFilesVersion + 1;
    List<String> files = supportedLanguages.map((lang) => "$lang\_$nextVersion.json").toList();
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

    final objectName = '$_normalizedPrefix$filePath';
    final object = storage.Object()..name = objectName;
    print("\n🚀 Uploading $filePath to $bucketName/$objectName...");
    try {
      await storageApi.objects.insert(object, bucketName, uploadMedia: media);
      print("✅ Uploaded: $bucketName/$objectName");
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
      final objects = await storageApi.objects.list(
        bucketName,
        prefix: folderPrefix ?? '',
      );
      if (objects.items == null || objects.items!.isEmpty) {
        print("📂 No files exist inside bucket : '$bucketName/${(folderPrefix ?? '')}'.");
        return;
      }
      for (var object in objects.items!) {
        try {
          await storageApi.objects.delete(bucketName, object.name!);
          print("🗑️  Deleting old JSON File: $bucketName/${object.name}");
        } catch (e) {
          // ignore files that don't match naming pattern
        }
      }
      print("✅ All Old JSON files are deleted inside the bucket : '$bucketName/${(folderPrefix ?? '')}'.");
    } catch (e) {
      print("❌ Error during deletion: $e");
    }
  }

  Future<void> _makeObjectPublic(String filePath) async {
    final objectName = '$_normalizedPrefix$filePath';
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
        print("🌍 The object '$bucketName/$objectName' is now public");
      } else {
        print("ℹ️ The object '$bucketName/$objectName' is already public");
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