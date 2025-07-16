class TufeData {
  final String groupName;
  final double changeRate;
  final bool isWebTufe;

  TufeData({
    required this.groupName,
    required this.changeRate,
  }) : isWebTufe = groupName == 'Web TÜFE';

  String get formattedChangeRate =>
      '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%';

  bool get isPositive => changeRate >= 0;

  String get displayName {
    // Grup isimlerini daha okunabilir hale getir
    switch (groupName) {
      case 'Alkollü içecekler ve tütün':
        return 'Alkollü içecekler ve tütün';
      case 'Gıda ve alkolsüz içecekler':
        return 'Gıda ve alkolsüz içecekler';
      case 'Çeşitli mal ve hizmetler':
        return 'Çeşitli mal ve hizmetler';
      default:
        return groupName;
    }
  }
}
