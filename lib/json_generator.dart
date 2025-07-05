/// This [JsonGenerator] class generate translation JSON files from an Excel sheet.
/// 
/// The [JsonGenerator] class reads an Excel sheet via [excelParser], extracts
/// per-language translation keys/values, and outputs formatted `.json` files for
/// each supported language (FR, EN, ES, DE, PT, NL, IT).
/// 
/// It also retrieves the latest JSON version from cloud storage (via [CloudFileUploader])
/// to increment file versions automatically when saving.
/// 
/// This is useful for automating multilingual translation workflows and keeping
/// JSON files up-to-date with a central Excel source.

import 'package:excel/excel.dart';
import 'package:translator_automation/cloud_file_uploader.dart';
import 'dart:io';
import 'dart:convert';
import 'excel_parser.dart';

/// Per-language translation maps to store the new translations data from excel file

class JsonGenerator {
  final ExcelParser excelParser;
  final Map<String, String> _fr = {};
  final Map<String, String> _en = {};
  final Map<String, String> _es = {};
  final Map<String, String> _de = {};
  final Map<String, String> _pt = {};
  final Map<String, String> _nl = {};
  final Map<String, String> _it = {};
  Sheet? excelSheet;
  List<String>? sheetHeader;
  Map<String, int>? sheetHeaderMap;
  final CloudFileUploader cloudFileUploader;
  int? oldTranslationsJsonFilesVersion;

  JsonGenerator({required this.excelParser, required this.cloudFileUploader}) {
    excelSheet = excelParser.fetchExcelSheet();
    sheetHeader = excelParser.extractSheetHeader(excelSheet);
    sheetHeaderMap = excelParser.sheetHeaderMap;
  }

  /// Generate all JSON files from the Excel sheet
  void generateJsonFiles() {
    _convertSheetToJsonMaps();
    _saveAllJsonFiles();
  }

  /// Helper function to Convert Excel rows into language maps
  void _convertSheetToJsonMaps() {
    int dataBeginRow = excelParser.excelFileConfig.headerBeginRow + 1;
    if (excelSheet != null && sheetHeaderMap != null) {
      // Add the initial "key" entry for each language map
      _fr["key"] = "fr_FR";
      _en["key"] = "en_EN";
      _es["key"] = "es_ES";
      _de["key"] = "de_DE";
      _pt["key"] = "pt_PT";
      _nl["key"] = "nl_NL";
      _it["key"] = "it_IT";

      for (int row = dataBeginRow; row < excelSheet!.rows.length; row++) {
        final key = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['key']!);
        _fr[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['fr']!);
        _en[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['en']!);
        _es[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['es']!);
        _de[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['de']!);
        _pt[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['pt']!);
        _nl[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['nl']!);
        _it[key] = _getCellValue(row, excelParser.excelFileConfig.languageExcelPositionMap['it']!);
      }
    }
  }


  /// Extract cell value
  String _getCellValue(int row, int headerIndex) {
    if (sheetHeader == null || sheetHeaderMap == null) return '';
    if (headerIndex >= sheetHeader!.length) return '';

    final columnKey = sheetHeader![headerIndex];
    final colIndex = sheetHeaderMap![columnKey];
    if (colIndex == null) return '';

    return excelSheet!.rows[row][colIndex]?.value?.toString() ?? '';
  }

  /// Write all JSON maps to files
  void _saveAllJsonFiles() async {
    Map<String, Map<String, String>> translations = {
      "fr_FR": _fr,
      "en_EN": _en,
      "es_ES": _es,
      "de_DE": _de,
      "pt_PT": _pt,
      "nl_NL": _nl,
      "it_IT": _it,
    };
    await getOldJsonFilesVersion();
    print("\n📝================== Step 3: Generating new JSONs & Delete old ones ========");
    for (var entry in translations.entries) {
      _writeJsonToFile(entry.value,"${entry.key}_${oldTranslationsJsonFilesVersion! + 1}.json");
    }
  }

  /// Write new JSON File based on translations Maps
  void _writeJsonToFile(Map<String, String> map, String fileName) {
    final jsonString = const JsonEncoder.withIndent('  ').convert(map);
    final file = File(fileName);
    file.writeAsStringSync(jsonString);
    print("✅ File saved: $fileName");
  }

  /// Get old JSON files version
  Future<void> getOldJsonFilesVersion() async {
    print("\n🔍================== Step 2: Versioning =============");
    oldTranslationsJsonFilesVersion = await cloudFileUploader.getOldJsonFilesVersion();
    print("🔄 Old JSON files version = $oldTranslationsJsonFilesVersion");
  }
}
