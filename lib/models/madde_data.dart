class MaddeData {
  final String maddeName;
  final double changeRate;

  MaddeData({
    required this.maddeName,
    required this.changeRate,
  });

  factory MaddeData.fromCsv(List<dynamic> row, int columnIndex) {
    return MaddeData(
      maddeName: row[1].toString().trim(),
      changeRate: double.tryParse(row[columnIndex].toString()) ?? 0.0,
    );
  }
}
