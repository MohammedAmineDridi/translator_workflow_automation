/// This configuration class [ExcelTranslationConfig] that defines params of excel file for parsing and extract header and data content

class ExcelTranslationConfig {
  final String sheetName;
  final int headerBeginRow;
  final int headerBeginCol;
  final String bucketName;
  final Map<String,int> languageExcelPositionMap;
  static const Map<String, int> defaultLanguageMap = {
    'fr': 0,
    'key': 1,
    'en': 2,
    'es': 3,
    'de': 4,
    'pt': 5,
    'nl': 6,
    'it': 7,
  };

  ExcelTranslationConfig({
    required this.sheetName,
    this.headerBeginRow = 0,
    this.headerBeginCol = 0,
    this.languageExcelPositionMap = defaultLanguageMap, // Put your language position in excel file here
    required this.bucketName,
  });

  @override
  String toString() {
  return 'ExcelTranslationConfig(sheetName: $sheetName, headerBeginRow: $headerBeginRow, '
         'headerBeginCol: $headerBeginCol, bucketName: $bucketName, '
         'languageExcelPositionMap: $languageExcelPositionMap)';
  }
}