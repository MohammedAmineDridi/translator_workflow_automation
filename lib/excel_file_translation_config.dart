/// This configuration class [ExcelTranslationConfig] that defines params of excel file for parsing and extract header and data content

class ExcelTranslationConfig {
  final String sheetName;
  final int headerBeginRow;
  final int headerBeginCol;
  final String bucketName;
  final Map<String,int> languageExcelPositionMap;

  ExcelTranslationConfig({
    required this.sheetName,
    this.headerBeginRow = 0,
    this.headerBeginCol = 0,
    /// Put your language position in excel file here
    this.languageExcelPositionMap = const {
    'fr': 0,
    'key': 1,
    'en': 2,
    'es': 3,
    'de': 4,
    'pt': 5,
    'nl': 6,
    'it': 7,
    },
    required this.bucketName,
  });
}