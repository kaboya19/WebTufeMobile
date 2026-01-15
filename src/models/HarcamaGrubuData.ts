export interface HarcamaGrubuData {
  groupName: string;
  changeRate: number;
}

export interface AnaGrupData {
  name: string;
}

export interface HarcamaGrubuEndeksData {
  tarih: string;
  endeks: number;
}

export interface HarcamaGrubuAylikData {
  tarih: string;
  degisimOrani: number;
}

export interface HarcamaGrubuIstatistik {
  yillikDegisim: number;
  aylikDegisim: number;
  selectedGrup: string;
}

export class HarcamaGrubuDataModel implements HarcamaGrubuData {
  groupName: string;
  changeRate: number;

  constructor(groupName: string, changeRate: number) {
    this.groupName = groupName;
    this.changeRate = changeRate;
  }

  static fromCsv(row: any[], columnIndex: number): HarcamaGrubuData {
    return new HarcamaGrubuDataModel(
      row[1]?.toString().trim() || '',
      parseFloat(row[columnIndex]?.toString() || '0') || 0.0
    );
  }
}

