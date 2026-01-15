import Papa from 'papaparse';
import {TufeDataModel} from '../models/TufeData';
import {GitHubCSVService} from './GitHubCSVService';

const MONTHS = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

export class CSVService {
  private static normalizeKey(name: string): string {
    return (name || '')
      .toLowerCase()
      .replace(/[\s,._-]+/g, '')
      .replace(/ı/g, 'i')
      .replace(/İ/g, 'i')
      .replace(/ö/g, 'o')
      .replace(/ü/g, 'u')
      .replace(/ğ/g, 'g')
      .replace(/ş/g, 's')
      .replace(/ç/g, 'c');
  }

  static async loadTufeData(): Promise<TufeDataModel[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaraylik.csv',
        false
      );

      const lines = csvData.split(/\r?\n/);

      const rows: any[][] = [];
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line) {
          try {
            const parsed = Papa.parse(line, {
              header: false,
              skipEmptyLines: true,
            });
            if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
              rows.push(parsed.data[0] as any[]);
            }
          } catch (e) {
            // Parse hatası (sessiz)
          }
        }
      }

      if (rows.length === 0) {
        throw new Error('CSV dosyası boş');
      }

      const tufeDataList: TufeDataModel[] = [];

      // İlk satır header, ondan sonraki satırları işle
      for (let i = 1; i < rows.length; i++) {
        if (rows[i].length < 2) {
          continue;
        }

        const groupName = rows[i][1]?.toString().trim() || '';

        if (!groupName) {
          continue;
        }

        // Son sütundaki veriyi al (en güncel ay)
        const lastValue = rows[i][rows[i].length - 1];
        let changeRate = 0.0;

        if (typeof lastValue === 'number') {
          changeRate = lastValue;
        } else if (typeof lastValue === 'string') {
          try {
            changeRate = parseFloat(lastValue) || 0.0;
          } catch (e) {
            changeRate = 0.0;
          }
        }

        tufeDataList.push(new TufeDataModel(groupName, changeRate));
        console.log(`Eklendi: ${groupName} = ${changeRate}`);
      }

      console.log(`Toplam ${tufeDataList.length} veri eklendi`);

      // Verileri değişim oranına göre büyükten küçüğe sırala
      tufeDataList.sort((a, b) => b.changeRate - a.changeRate);

      return tufeDataList;
    } catch (e) {
      throw new Error(`CSV veri yükleme hatası: ${e}`);
    }
  }

  static getCurrentMonth(): string {
    const now = new Date();
    return MONTHS[now.getMonth()];
  }

  static async getMonthFromCSV(): Promise<string> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaraylik.csv',
        false
      );

      const lines = csvData.split(/\r?\n/);
      const rows: any[][] = [];

      for (const line of lines) {
        const trimmedLine = line.trim();
        if (trimmedLine) {
          try {
            const parsed = Papa.parse(trimmedLine, {
              header: false,
              skipEmptyLines: true,
            });
            if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
              rows.push(parsed.data[0] as any[]);
            }
          } catch (e) {
            // Parse hatalarını sessizce atla
          }
        }
      }

      if (rows.length === 0 || rows[0].length < 3) {
        return this.getCurrentMonth();
      }

      // Header satırından son sütundaki tarihi al
      const lastDateString = rows[0][rows[0].length - 1]?.toString().trim() || '';

      // Tarih formatını parse et (2025-08-31 formatında)
      try {
        const lastDate = new Date(lastDateString);
        return MONTHS[lastDate.getMonth()];
      } catch (e) {
        return this.getCurrentMonth();
      }
    } catch (e) {
      return this.getCurrentMonth();
    }
  }

  static async getTufeMonthlyChange(): Promise<number> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaraylik.csv',
        false
      );

      const lines = csvData.split(/\r?\n/);
      const rows: any[][] = [];

      for (const line of lines) {
        const trimmedLine = line.trim();
        if (trimmedLine) {
          try {
            const parsed = Papa.parse(trimmedLine, {
              header: false,
              skipEmptyLines: true,
            });
            if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
              rows.push(parsed.data[0] as any[]);
            }
          } catch (e) {
            // Parse hatalarını sessizce atla
          }
        }
      }

      if (rows.length === 0) {
        throw new Error('CSV dosyası boş');
      }

      // Find the "Web TÜFE" row
      for (let i = 1; i < rows.length; i++) {
        if (rows[i].length >= 2) {
          const groupName = rows[i][1]?.toString().trim() || '';
          if (groupName === 'Web TÜFE') {
            // Get the last column (latest monthly change)
            const lastValue = rows[i][rows[i].length - 1]?.toString().trim() || '';
            try {
              return parseFloat(lastValue) || 0.0;
            } catch (e) {
              return 0.0;
            }
          }
        }
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static async getAvailableDates(): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaraylik.csv',
        false
      );

      const lines = csvData.split(/\r?\n/);
      const rows: any[][] = [];

      for (const line of lines) {
        const trimmedLine = line.trim();
        if (trimmedLine) {
          try {
            const parsed = Papa.parse(trimmedLine, {
              header: false,
              skipEmptyLines: true,
            });
            if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
              rows.push(parsed.data[0] as any[]);
            }
          } catch (e) {
            // Parse hatalarını sessizce atla
          }
        }
      }

      if (rows.length === 0 || rows[0].length < 3) {
        return [];
      }

      // Header satırından tarihleri al (2. sütundan itibaren)
      const dates: string[] = [];
      for (let i = 2; i < rows[0].length; i++) {
        const dateStr = rows[0][i]?.toString().trim() || '';
        if (dateStr) {
          dates.push(dateStr);
        }
      }

      return dates;
    } catch (e) {
      // Tarih listesi yükleme hatası (sessiz)
      return [];
    }
  }

  static async loadTufeDataForDate(
    selectedDate: string
  ): Promise<TufeDataModel[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaraylik.csv',
        false
      );

      const lines = csvData.split(/\r?\n/);
      const rows: any[][] = [];

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line) {
          try {
            const parsed = Papa.parse(line, {
              header: false,
              skipEmptyLines: true,
            });
            if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
              rows.push(parsed.data[0] as any[]);
            }
          } catch (e) {
            // Parse hatası (sessiz)
          }
        }
      }

      if (rows.length === 0) {
        throw new Error('CSV dosyası boş');
      }

      // Header satırından seçili tarihin sütun indeksini bul
      let dateColumnIndex = -1;
      for (let i = 2; i < rows[0].length; i++) {
        const dateStr = rows[0][i]?.toString().trim() || '';
        if (dateStr === selectedDate) {
          dateColumnIndex = i;
          break;
        }
      }

      if (dateColumnIndex === -1) {
        throw new Error(`Seçili tarih bulunamadı: ${selectedDate}`);
      }

      const tufeDataList: TufeDataModel[] = [];

      // İlk satır header, ondan sonraki satırları işle
      for (let i = 1; i < rows.length; i++) {
        if (rows[i].length < dateColumnIndex + 1) {
          continue;
        }

        const groupName = rows[i][1]?.toString().trim() || '';
        if (!groupName) {
          continue;
        }

        // Seçili tarih sütunundaki veriyi al
        const value = rows[i][dateColumnIndex];
        let changeRate = 0.0;

        if (typeof value === 'number') {
          changeRate = value;
        } else if (typeof value === 'string') {
          try {
            changeRate = parseFloat(value) || 0.0;
          } catch (e) {
            changeRate = 0.0;
          }
        }

        tufeDataList.push(new TufeDataModel(groupName, changeRate));
      }

      // Verileri değişim oranına göre büyükten küçüğe sırala
      tufeDataList.sort((a, b) => b.changeRate - a.changeRate);

      return tufeDataList;
    } catch (e) {
      throw new Error(`CSV veri yükleme hatası: ${e}`);
    }
  }

  static async loadContributionData(
    selectedDate?: string
  ): Promise<Array<{groupName: string; contribution: number; normalizedKey: string}>> {
    const csvData = await GitHubCSVService.loadCSVFromGitHub('katkıpayları.csv', true);
    const lines = csvData.split(/\r?\n/).filter((l) => l.trim().length > 0);
    if (lines.length < 2) {
      return [];
    }

    const rows: any[][] = [];
    for (const line of lines) {
      try {
        const parsed = Papa.parse(line, {header: false, skipEmptyLines: true});
        if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
          rows.push(parsed.data[0] as any[]);
        }
      } catch {
        // ignore bad line
      }
    }
    if (rows.length < 2) return [];

    const header = rows[0];
    let dataRow: any[] | null = null;

    // If a date is provided, try to match that row
    if (selectedDate) {
      const match = rows.find((r, idx) => idx > 0 && `${r[0] || ''}`.trim() === selectedDate);
      if (match) dataRow = match;
    }

    // Fallback: last non-empty data row
    if (!dataRow) {
      for (let i = rows.length - 1; i >= 1; i--) {
        const r = rows[i];
        const hasValue = r.some((v, idx) => idx > 0 && v !== null && `${v}`.trim() !== '');
        if (hasValue) {
          dataRow = r;
          break;
        }
      }
    }

    if (!dataRow) return [];

    const items: Array<{groupName: string; contribution: number; normalizedKey: string}> = [];
    for (let col = 1; col < header.length; col++) {
      const groupName = header[col]?.toString().trim() || '';
      if (!groupName) continue;
      const rawVal = dataRow[col];
      let contribution = 0;
      if (typeof rawVal === 'number') contribution = rawVal;
      else if (typeof rawVal === 'string') {
        const parsed = parseFloat(rawVal.replace(',', '.'));
        if (!isNaN(parsed)) contribution = parsed;
      }
      items.push({
        groupName,
        contribution,
        normalizedKey: this.normalizeKey(groupName),
      });
    }
    return items;
  }

  static getMonthFromDate(dateString: string): string {
    try {
      const date = new Date(dateString);
      return MONTHS[date.getMonth()];
    } catch (e) {
      return '';
    }
  }
}

