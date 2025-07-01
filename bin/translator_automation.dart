import 'dart:io';
import 'package:translator_automation/excel_parser.dart';
import 'package:translator_automation/json_generator.dart';
import 'package:translator_automation/cloud_file_uploader.dart';
import 'package:translator_automation/excel_file_translation_config.dart';

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
      sheetName: "Mobile",
      headerBeginRow: 2,
      headerBeginCol: 2,
      bucketName: "test_translation_bucket1",
    );

    final excelParser = ExcelParser(
      excelFilePath: excelFilePath,
      excelFileConfig: excelFileconfig,
    );

    final uploader = await CloudFileUploader.create(
      bucketName: excelFileconfig.bucketName,
      //folderPrefix: "test_translation_sub_bucket2",
    );

    final generator = JsonGenerator(
      excelParser: excelParser,
      cloudFileUploader: uploader,
    );

    generator.generateJsonFiles();
    await uploader.uploadNewJsonFiles().then((value) => {
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
