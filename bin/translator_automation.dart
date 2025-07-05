import 'dart:io';
import 'package:translator_automation/excel_parser.dart';
import 'package:translator_automation/json_generator.dart';
import 'package:translator_automation/cloud_file_uploader.dart';
import 'package:translator_automation/excel_file_translation_config.dart';
import 'package:translator_automation/remote_config_cloud_function.dart';

Future<void> main(List<String> arguments) async {
  stdout.write("📥 Enter the Excel (.xlsx) filename (with path if needed): ");
  final inputFilePath = stdin.readLineSync();

  if (inputFilePath == null || inputFilePath.isEmpty) {
    print("❌ No input file provided. Aborting.");
    return;
  }

  final file = File(inputFilePath);
  if (!file.existsSync()) {
    print("❌ File '$inputFilePath' not found.");
    return;
  }

  await runTranslationPipeline(excelFilePath: inputFilePath);
  print('\nPress ENTER to exit...');
  stdin.readLineSync();
}

/// Orchestrates the full Excel to Google Cloud Platform translation pipeline.
Future<void> runTranslationPipeline({required String excelFilePath}) async {
  try {
    final excelFileconfig = ExcelTranslationConfig(
      sheetName: "Mobile", // Put your sheetName here
      headerBeginRow: 2, // Put your headerBeginRow here (see screenShot in readme file)
      headerBeginCol: 2,// Put your headerBeginCol here (see screenShot in readme file)
      bucketName: "test_translation_bucket1", // Put your bucketName here
    );

    final excelParser = ExcelParser(
      excelFilePath: excelFilePath,
      excelFileConfig: excelFileconfig,
    );

    final uploader = await CloudFileUploader.create(
      bucketName: excelFileconfig.bucketName,
      //folderPrefix: "sub_bucket1/sub_sub_bucket1", // if you have a buckets hierarchy put your folder prefix here ,eg:{yourBucketName}/SubBucket1/....
    );

    final generator = JsonGenerator(
      excelParser: excelParser,
      cloudFileUploader: uploader,
    );

    generator.generateJsonFiles();

    await uploader.uploadNewJsonFiles().then((value) => {
      // (OPTIONAL) add remote config increment lang variable value +1 (to track the jsons version in firebase remote config var)
      RemoteConfigCloudFunction(callStatus: false).notifyLangVersionUpdate(projectId: "",region: "",cloudFunctionName: ""), // put your {projectID,Region,CloudFunctionName}
      print("\n✅================== ✅ DONE ✅ ========================"),
      print("🎉 Translation pipeline completed successfully 😁")
    }).onError((error, stackTrace) => {
      print("\n❌ Translation pipeline has an error while upload new json files")
    });
    uploader.dispose();
    
  } catch (e, stack) {
    print('❌ An error occurred in running the translator automation pipeline : $e');
    print(stack);
  }
}
