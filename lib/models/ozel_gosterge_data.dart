class OzelGostergeData {
  final String gostergeName;
  final List<double> dailyValues;
  final List<String> dates;
  final List<double> monthlyChanges;
  final List<String> monthlyDates;

  OzelGostergeData({
    required this.gostergeName,
    required this.dailyValues,
    required this.dates,
    required this.monthlyChanges,
    required this.monthlyDates,
  });

  // Yılbaşından itibaren değişim hesapla (son değer - 100)
  double getYearToDateChange() {
    if (dailyValues.isEmpty) return 0.0;
    return dailyValues.last - 100.0;
  }

  // En son aylık değişim oranını al
  double getLatestMonthlyChange() {
    if (monthlyChanges.isEmpty) return 0.0;
    return monthlyChanges.last;
  }
}
