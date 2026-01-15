export interface OzelGostergeData {
  gostergeName: string;
  dailyValues: number[];
  dates: string[];
  monthlyChanges: number[];
  monthlyDates: string[];
}

export class OzelGostergeDataModel implements OzelGostergeData {
  gostergeName: string;
  dailyValues: number[];
  dates: string[];
  monthlyChanges: number[];
  monthlyDates: string[];

  constructor(
    gostergeName: string,
    dailyValues: number[],
    dates: string[],
    monthlyChanges: number[],
    monthlyDates: string[]
  ) {
    this.gostergeName = gostergeName;
    this.dailyValues = dailyValues;
    this.dates = dates;
    this.monthlyChanges = monthlyChanges;
    this.monthlyDates = monthlyDates;
  }

  getYearToDateChange(): number {
    if (this.dailyValues.length === 0) return 0.0;
    return this.dailyValues[this.dailyValues.length - 1] - 100.0;
  }

  getLatestMonthlyChange(): number {
    if (this.monthlyChanges.length === 0) return 0.0;
    return this.monthlyChanges[this.monthlyChanges.length - 1];
  }
}

