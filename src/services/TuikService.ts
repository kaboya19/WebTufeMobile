import Papa from 'papaparse';
import {GitHubCSVService} from './GitHubCSVService';

export class TuikService {
  private static normalizeKey(s: string): string {
    return (s || '')
      .toLowerCase()
      .trim()
      .replace(/\u00a0/g, ' ')
      .replace(/[’'"]/g, '')
      .replace(/[(),.]/g, ' ')
      .replace(/\s+/g, ' ')
      .replace(/ğ/g, 'g')
      .replace(/ü/g, 'u')
      .replace(/ş/g, 's')
      .replace(/ı/g, 'i')
      .replace(/ö/g, 'o')
      .replace(/ç/g, 'c');
  }

  // Web ana grup isimlerini TÜİK CSV kolon isimlerine map etmek için
  private static mapToTuikGrupName(grupName: string): string {
    const trimmed = (grupName || '').trim();
    if (trimmed === 'Eğlence,spor ve kültür') {
      return 'Eğlence, dinlence, spor ve kültür';
    }
    return grupName;
  }

  private static findColumnIndex(headerRow: any[], columnName: string): number {
    const target = this.normalizeKey(columnName);
    // Direct match
    for (let i = 0; i < headerRow.length; i++) {
      const h = this.normalizeKey(headerRow[i]?.toString() || '');
      if (h === target) return i;
    }
    // Fuzzy: contains
    for (let i = 0; i < headerRow.length; i++) {
      const h = this.normalizeKey(headerRow[i]?.toString() || '');
      if (h && (h.includes(target) || target.includes(h))) return i;
    }
    return -1;
  }

  private static async loadTuikColumnFromCsv(
    fileName: string,
    columnName: string,
    outputKey: string,
    convertDateToDDMMYYYY: boolean
  ): Promise<{dates: string[]; data: {[key: string]: number[]}}> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(fileName);
      const lines = csvData.split(/\r?\n/);

      if (lines.length === 0) return {dates: [], data: {}};

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      const colIndex = this.findColumnIndex(headerRow, columnName);
      if (colIndex === -1) return {dates: [], data: {}};

      const dates: string[] = [];
      const values: number[] = [];

      for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;
        try {
          const parsed = Papa.parse(lines[i], {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            parsed.data[0].length > colIndex
          ) {
            const row = parsed.data[0] as any[];
            let date = row[0]?.toString().trim() || '';

            if (convertDateToDDMMYYYY) {
              try {
                const dateParts = date.split('-');
                if (dateParts.length === 3) {
                  date = `${dateParts[2]}.${dateParts[1]}.${dateParts[0]}`;
                }
              } catch (e) {
                // keep original
              }
            }

            const rawValue = row[colIndex]?.toString().trim() ?? '';
            const v = parseFloat(rawValue || '0');
            if (!Number.isFinite(v)) continue;

            dates.push(date);
            values.push(v);
          }
        } catch (e) {
          // skip
        }
      }

      return {
        dates,
        data: {
          [outputKey]: values,
        },
      };
    } catch (e) {
      console.log('TÜİK kolon veri yükleme hatası:', e);
      return {dates: [], data: {}};
    }
  }

  // Ana gruplar (TÜİK) - endeks (tuikytd.csv)
  static async loadTuikAnaGrupEndeksData(grupName: string): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    // tüik_anagruplarv2.csv: YYYY-MM-DD tarihli ve ana grup kolonları mevcut
    const csvGrupName = this.mapToTuikGrupName(grupName);
    return await this.loadTuikColumnFromCsv(
      'tüik_anagruplarv2.csv',
      csvGrupName,
      `TÜİK ${grupName}`, // output key her zaman orijinal isimle kalsın
      true
    );
  }

  // Özel kapsamlı göstergeler (TÜİK) - endeks (tuikozelgostergelerytd.csv)
  static async loadTuikOzelGostergeEndeksData(gostergeName: string): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    // tuikozelgostergelerytd.csv: YYYY-MM-DD tarihli ve özel gösterge kolonları mevcut
    return await this.loadTuikColumnFromCsv(
      'tuikozelgostergelerytd.csv',
      gostergeName,
      `TÜİK ${gostergeName}`,
      true
    );
  }

  // Özel kapsamlı göstergeler (TÜİK) - aylık değişim (tuikozelgostergeler.csv)
  static async loadTuikOzelGostergeData(gostergeName: string): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    // tuikozelgostergeler.csv: YYYY-MM-DD tarihli ve özel gösterge kolonları mevcut
    return await this.loadTuikColumnFromCsv(
      'tuikozelgostergeler.csv',
      gostergeName,
      `TÜİK ${gostergeName}`,
      true
    );
  }

  // Ana gruplar (TÜİK) - aylık değişim (tuikaylik.csv)
  static async loadTuikAnaGrupData(grupName: string): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    // tüik_anagruplaraylikv2.csv: YYYY-MM-DD tarihli ve ana grup aylık değişim kolonları mevcut
    // date conversion gerekmiyor; AnaGruplarPage year-month match yapıyor
    const csvGrupName = this.mapToTuikGrupName(grupName);
    return await this.loadTuikColumnFromCsv(
      'tüik_anagruplaraylikv2.csv',
      csvGrupName,
      `TÜİK ${grupName}`, // output key orijinal isim
      false
    );
  }

  // Harcama grupları (TÜİK) - endeks (tuikytd.csv)
  // Harcama grubu isimleri tuikytd.csv içinde kolon olarak yer alabilir (alt kırılımlar dahil).
  static async loadTuikHarcamaGrubuEndeksData(harcamaGrubu: string): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    return await this.loadTuikColumnFromCsv(
      'tuikytd.csv',
      harcamaGrubu,
      `TÜİK ${harcamaGrubu}`,
      true
    );
  }

  // Harcama grupları (TÜİK) - aylık değişim (tuikaylik.csv)
  static async loadTuikHarcamaGrubuData(harcamaGrubu: string): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    return await this.loadTuikColumnFromCsv(
      'tuikaylik.csv',
      harcamaGrubu,
      `TÜİK ${harcamaGrubu}`,
      false
    );
  }

  static async loadTuikAylikData(): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('tuikaylik.csv');
      const lines = csvData.split(/\r?\n/);

      if (lines.length === 0) {
        return {dates: [], data: {}};
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      let genelColumnIndex = -1;
      for (let i = 0; i < headerRow.length; i++) {
        if (headerRow[i]?.toString().trim() === 'Genel') {
          genelColumnIndex = i;
          break;
        }
      }

      if (genelColumnIndex === -1) {
        return {dates: [], data: {}};
      }

      const dates: string[] = [];
      const genelValues: number[] = [];

      for (let i = 1; i < lines.length; i++) {
        if (lines[i].trim()) {
          try {
            const parsed = Papa.parse(lines[i], {
              header: false,
              skipEmptyLines: true,
            });
            if (
              parsed.data.length > 0 &&
              Array.isArray(parsed.data[0]) &&
              parsed.data[0].length > genelColumnIndex
            ) {
              const row = parsed.data[0] as any[];
              const date = row[0]?.toString().trim() || '';
              const value = parseFloat(row[genelColumnIndex]?.toString() || '0') || 0.0;

              dates.push(date);
              genelValues.push(value);
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }

      return {
        dates: dates,
        data: {
          'TÜİK TÜFE': genelValues,
        },
      };
    } catch (e) {
      console.log('TÜİK aylık veri yükleme hatası:', e);
      return {dates: [], data: {}};
    }
  }

  static async loadTuikEndeksData(): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('tüik.csv');
      const lines = csvData.split(/\r?\n/);

      if (lines.length === 0) {
        return {dates: [], data: {}};
      }

      const dates: string[] = [];
      const genelValues: number[] = [];

      // tüik.csv formatı: ilk satır header (,TÜİK), sonraki satırlar tarih,değer
      for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;
        try {
          const parsed = Papa.parse(lines[i], {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            parsed.data[0].length >= 2
          ) {
            const row = parsed.data[0] as any[];
            let date = row[0]?.toString().trim() || '';
            
            // Tarihi DD.MM.YYYY formatına çevir
            try {
              const dateParts = date.split('-');
              if (dateParts.length === 3) {
                date = `${dateParts[2]}.${dateParts[1]}.${dateParts[0]}`;
              }
            } catch (e) {
              // Keep original format
            }

            const value = parseFloat(row[1]?.toString() || '0') || 0.0;

            dates.push(date);
            genelValues.push(value);
          }
        } catch (e) {
          // Skip parse errors
          continue;
        }
      }

      return {
        dates: dates,
        data: {
          'TÜİK TÜFE': genelValues,
        },
      };
    } catch (e) {
      console.log('TÜİK endeks veri yükleme hatası:', e);
      return {dates: [], data: {}};
    }
  }

  static async loadTuikMonthlyChangeData(): Promise<{
    dates: string[];
    data: {[key: string]: number[]};
  }> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('tuikaylik.csv');
      const lines = csvData.split(/\r?\n/);

      if (lines.length === 0) {
        return {dates: [], data: {}};
      }

      const dates: string[] = [];
      const tuikValues: number[] = [];

      // Veri satırlarından tarih ve TÜFE değerlerini oku (ilk satır header, atla)
      for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;
        try {
          const parsed = Papa.parse(lines[i], {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            parsed.data[0].length >= 2
          ) {
            const row = parsed.data[0] as any[];
            // İlk kolon tarih (2025-01-31 formatında)
            const tarihStr = row[0]?.toString().trim() || '';
            // İkinci kolon TÜFE değeri
            const value = parseFloat(row[1]?.toString() || '0') || 0.0;

            if (tarihStr && tarihStr.includes('-')) {
              try {
                const dateParts = tarihStr.split('-');
                if (dateParts.length === 3) {
                  const monthName = MONTH_NAMES[dateParts[1]] || dateParts[1];
                  dates.push(`${monthName} ${dateParts[0]}`);
                  tuikValues.push(value);
                }
              } catch (e) {
                // Skip invalid dates
              }
            }
          }
        } catch (e) {
          // Skip parse errors
          continue;
        }
      }

      return {
        dates: dates,
        data: {
          'TÜİK TÜFE': tuikValues,
        },
      };
    } catch (e) {
      console.log('TÜİK aylık değişim veri yükleme hatası:', e);
      return {dates: [], data: {}};
    }
  }
}

const MONTH_NAMES: {[key: string]: string} = {
  '01': 'Ocak',
  '02': 'Şubat',
  '03': 'Mart',
  '04': 'Nisan',
  '05': 'Mayıs',
  '06': 'Haziran',
  '07': 'Temmuz',
  '08': 'Ağustos',
  '09': 'Eylül',
  '10': 'Ekim',
  '11': 'Kasım',
  '12': 'Aralık',
};

