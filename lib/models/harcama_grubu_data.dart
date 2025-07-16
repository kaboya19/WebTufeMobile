class HarcamaGrubuData {
  final String groupName;
  final double changeRate;

  HarcamaGrubuData({
    required this.groupName,
    required this.changeRate,
  });

  factory HarcamaGrubuData.fromCsv(List<dynamic> row, int columnIndex) {
    return HarcamaGrubuData(
      groupName: row[1].toString().trim(),
      changeRate: double.tryParse(row[columnIndex].toString()) ?? 0.0,
    );
  }
}

class AnaGrupData {
  final String name;

  AnaGrupData({required this.name});
}

class HarcamaGrubuEndeksData {
  final String tarih;
  final double endeks;

  HarcamaGrubuEndeksData({
    required this.tarih,
    required this.endeks,
  });
}

class HarcamaGrubuAylikData {
  final String tarih;
  final double degisimOrani;

  HarcamaGrubuAylikData({
    required this.tarih,
    required this.degisimOrani,
  });
}

class HarcamaGrubuIstatistik {
  final double yillikDegisim;
  final double aylikDegisim;
  final String selectedGrup;

  HarcamaGrubuIstatistik({
    required this.yillikDegisim,
    required this.aylikDegisim,
    required this.selectedGrup,
  });
}
