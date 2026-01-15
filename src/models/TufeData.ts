export interface TufeData {
  groupName: string;
  changeRate: number;
  isWebTufe: boolean;
}

export class TufeDataModel implements TufeData {
  groupName: string;
  changeRate: number;

  constructor(groupName: string, changeRate: number) {
    this.groupName = groupName;
    this.changeRate = changeRate;
  }

  get isWebTufe(): boolean {
    return this.groupName === 'Web TÜFE';
  }

  get formattedChangeRate(): string {
    return `${this.changeRate >= 0 ? '+' : ''}${this.changeRate.toFixed(2)}%`;
  }

  get isPositive(): boolean {
    return this.changeRate >= 0;
  }

  get displayName(): string {
    switch (this.groupName) {
      case 'Alkollü içecekler ve tütün':
        return 'Alkollü içecekler ve tütün';
      case 'Gıda ve alkolsüz içecekler':
        return 'Gıda ve alkolsüz içecekler';
      case 'Çeşitli mal ve hizmetler':
        return 'Çeşitli mal ve hizmetler';
      default:
        return this.groupName;
    }
  }
}

