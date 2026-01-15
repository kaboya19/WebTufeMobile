import Papa from 'papaparse';
import {GitHubCSVService} from './GitHubCSVService';
import {OzelGostergeData, OzelGostergeDataModel} from '../models/OzelGostergeData';

export class OzelGostergelerService {
  // Backwards-compatible aliases (page code expects these names)
  static async getIndicatorNames(): Promise<string[]> {
    return await this.getAvailableIndicators();
  }

  static async loadOzelGostergeData(selectedIndicator: string): Promise<OzelGostergeData> {
    return await this.loadIndicatorData(selectedIndicator);
  }

  static async getAvailableIndicators(): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'ozel_gostergeler.csv'
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        throw new Error('ozel_gostergeler.csv dosyası boş');
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      const indicators: string[] = [];
      for (let i = 1; i < headerRow.length; i++) {
        const indicator = headerRow[i]?.toString().trim() || '';
        if (indicator) {
          indicators.push(indicator);
        }
      }

      return indicators;
    } catch (e) {
      throw new Error(`Göstergeler yükleme hatası: ${e}`);
    }
  }

  static async loadIndicatorData(
    selectedIndicator: string
  ): Promise<OzelGostergeData> {
    try {
      const dailyData = await this.loadDailyData(selectedIndicator);
      const monthlyData = await this.loadMonthlyData(selectedIndicator);

      // Return the model instance (page uses helper methods like getYearToDateChange).
      return new OzelGostergeDataModel(
        selectedIndicator,
        dailyData.values,
        dailyData.dates,
        monthlyData.values,
        monthlyData.dates
      );
    } catch (e) {
      throw new Error(`Gösterge verisi yükleme hatası: ${e}`);
    }
  }

  private static async loadDailyData(selectedIndicator: string): Promise<{
    values: number[];
    dates: string[];
  }> {
    const csvData = await GitHubCSVService.loadCSVFromGitHub(
      'ozel_gostergeler.csv'
    );

    const lines = csvData.split(/\r?\n/);
    if (lines.length === 0) {
      throw new Error('ozel_gostergeler.csv dosyası boş');
    }

    const parsedHeader = Papa.parse(lines[0], {
      header: false,
      skipEmptyLines: true,
    });
    const headerRow =
      parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
        ? (parsedHeader.data[0] as any[])
        : [];

    let indicatorColumnIndex = -1;
    for (let i = 0; i < headerRow.length; i++) {
      if (headerRow[i]?.toString().trim() === selectedIndicator) {
        indicatorColumnIndex = i;
        break;
      }
    }

    if (indicatorColumnIndex === -1) {
      throw new Error(`Seçilen gösterge bulunamadı: ${selectedIndicator}`);
    }

    const values: number[] = [];
    const dates: string[] = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line) {
        try {
          const parsed = Papa.parse(line, {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            parsed.data[0].length > indicatorColumnIndex
          ) {
            const row = parsed.data[0] as any[];
            const date = row[0]?.toString().trim() || '';
            const valueStr = row[indicatorColumnIndex]?.toString().trim() || '';
            const value = parseFloat(valueStr) || 0.0;

            if (date && value !== 0.0) {
              dates.push(date);
              values.push(value);
            }
          }
        } catch (e) {
          // Skip parse errors
        }
      }
    }

    return {values, dates};
  }

  private static async loadMonthlyData(selectedIndicator: string): Promise<{
    values: number[];
    dates: string[];
  }> {
    const csvData = await GitHubCSVService.loadCSVFromGitHub(
      'ozelgostergeleraylik.csv'
    );

    const lines = csvData.split(/\r?\n/);
    if (lines.length === 0) {
      throw new Error('ozelgostergeleraylik.csv dosyası boş');
    }

    const parsedHeader = Papa.parse(lines[0], {
      header: false,
      skipEmptyLines: true,
    });
    const headerRow =
      parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
        ? (parsedHeader.data[0] as any[])
        : [];

    const monthlyDates: string[] = [];
    for (let i = 2; i < headerRow.length; i++) {
      const date = headerRow[i]?.toString().trim() || '';
      if (date && date.includes('-')) {
        monthlyDates.push(date);
      }
    }

    const monthlyValues: number[] = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line) {
        try {
          const parsed = Papa.parse(line, {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            parsed.data[0].length >= 2
          ) {
            const row = parsed.data[0] as any[];
            const rowIndicator = row[1]?.toString().trim() || '';

            if (rowIndicator === selectedIndicator) {
              for (
                let j = 2;
                j < row.length && j < monthlyDates.length + 2;
                j++
              ) {
                const value = parseFloat(row[j]?.toString() || '0') || 0.0;
                monthlyValues.push(value);
              }
              break;
            }
          }
        } catch (e) {
          // Skip parse errors
        }
      }
    }

    return {values: monthlyValues, dates: monthlyDates};
  }

  /**
   * Yıllık CSV'den son değeri okur (yıllık değişim için)
   * @param indicatorName Gösterge adı
   * @returns Yıllık değişim değeri (son satırdaki değer)
   */
  static async getYearlyChange(indicatorName: string): Promise<number> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('özelgöstergeleryıllık.csv', true);
      const lines = csvData.split(/\r?\n/).filter(line => line.trim());
      
      if (lines.length < 2) {
        console.log('özelgöstergeleryıllık.csv dosyası yeterli veri içermiyor');
        return 0.0;
      }
      
      // İlk satır header
      const headerLine = lines[0];
      const parsedHeader = Papa.parse(headerLine, {
        header: false,
        skipEmptyLines: true,
      });
      
      if (parsedHeader.data.length === 0 || !Array.isArray(parsedHeader.data[0])) {
        console.log('özelgöstergeleryıllık.csv header parse edilemedi');
        return 0.0;
      }
      
      const headerRow = parsedHeader.data[0] as any[];
      
      // Gösterge adının sütun index'ini bul
      let columnIndex = -1;
      for (let i = 0; i < headerRow.length; i++) {
        if (headerRow[i]?.toString().trim() === indicatorName) {
          columnIndex = i;
          break;
        }
      }
      
      if (columnIndex === -1) {
        console.log(`özelgöstergeleryıllık.csv'de gösterge bulunamadı: ${indicatorName}`);
        return 0.0;
      }
      
      // Son satırı parse et (boş satırları atla)
      let lastLine = '';
      for (let i = lines.length - 1; i >= 0; i--) {
        const line = lines[i].trim();
        if (line && !line.startsWith(',')) {
          lastLine = line;
          break;
        }
      }
      
      if (!lastLine) {
        console.log('özelgöstergeleryıllık.csv dosyasında geçerli veri satırı bulunamadı');
        return 0.0;
      }
      
      const parsed = Papa.parse(lastLine, {
        header: false,
        skipEmptyLines: true,
      });
      
      if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
        const row = parsed.data[0] as any[];
        if (row.length > columnIndex) {
          const valueStr = row[columnIndex]?.toString().trim() || '';
          if (valueStr) {
            const value = parseFloat(valueStr);
            if (!isNaN(value)) {
              return value;
            }
          }
        }
      }
      
      console.log(`özelgöstergeleryıllık.csv'den değer okunamadı: ${indicatorName}`);
      return 0.0;
    } catch (e) {
      console.log(`Yıllık değişim okuma hatası (${indicatorName}):`, e);
      return 0.0;
    }
  }
}

