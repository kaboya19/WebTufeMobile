export interface MaddeData {
  maddeName: string;
  changeRate: number;
}

export class MaddeDataModel implements MaddeData {
  maddeName: string;
  changeRate: number;

  constructor(maddeName: string, changeRate: number) {
    this.maddeName = maddeName;
    this.changeRate = changeRate;
  }

  static fromCsv(row: any[], columnIndex: number): MaddeData {
    return new MaddeDataModel(
      row[1]?.toString().trim() || '',
      parseFloat(row[columnIndex]?.toString() || '0') || 0.0
    );
  }
}

