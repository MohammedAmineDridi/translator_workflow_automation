/// This [ExcelParser] class parse and extract structured data from an Excel file.
///
/// The [ExcelParser] is used to:
/// - Open and read an Excel file from a specified file path.
/// - Fetch a specific sheet by name.
/// - Extract header information from the sheet starting at a configurable row and column.
/// - Generate a map [sheetHeaderMap] that links header titles (like "EN", "FR - Key", etc.)
///   to their corresponding column indexes.
///
/// This class is especially useful when working with multilingual data
/// or localized string mappings from Excel files.

import 'package:excel/excel.dart';
import 'dart:io';
import 'package:translator_automation/excel_file_translation_config.dart';

class ExcelParser {
  final String excelFilePath;
  final ExcelTranslationConfig excelFileConfig;
  Map<String, int> sheetHeaderMap = {};

  ExcelParser({required this.excelFilePath,required this.excelFileConfig});

  /// Parses the Excel file and returns the desired fetched sheet if it exists.
  /// Returns null if the file or the sheet is invalid.
  Sheet? fetchExcelSheet() {
    final file = File(excelFilePath);
    if (!file.existsSync()) {
      print("❌ Excel file $excelFilePath doesn't exist!");
      return null;
    }
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    for (var sheetName in excel.tables.keys) {
      if (sheetName == excelFileConfig.sheetName) {
        print("\n📄================== Step 1: Excel Parsing ==================");
        print("✅ Excel sheet '${excelFileConfig.sheetName}' found.");
        final sheet = excel.tables[sheetName];
        if (sheet != null && sheet.maxRows > 0) {
          return sheet;
        } else {
          print("❌ Excel Sheet '$sheetName' exists but contains no data.");
          return null;
        }
      }
    }
    print("❌ Excel Sheet named '${excelFileConfig.sheetName}' not found.");
    return null;
  }

  /// Extract excel Sheet Header
  /// Generate sheetHeaderMap (this map contain : key = lang 'FR,EN,FR - Key,....' and value = col)
  List<String> extractSheetHeader(Sheet? sheet) {
    List<String>? header = [];
    if (sheet != null) {
      for (int col = excelFileConfig.headerBeginCol; col < sheet.maxColumns; col++) {
        if (sheet.rows[excelFileConfig.headerBeginRow][col]!.value != null) {
          header.add(sheet.rows[excelFileConfig.headerBeginRow][col]!.value.toString());
          sheetHeaderMap.addAll({sheet.rows[excelFileConfig.headerBeginRow][col]!.value.toString(): col});
        }
      }
    }
    return header;
  }
}
