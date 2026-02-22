import Papa from 'papaparse';
import {GitHubCSVService} from './GitHubCSVService';
import {MaddeData} from '../models/MaddeData';

export class MaddelerService {
  static async loadAnaGruplar(): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('gruplar.csv');

      const lines = csvData.split(/\r?\n/);
      const anaGruplar: string[] = [];

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
              parsed.data[0].length > 0
            ) {
              const anaGrupAdi = parsed.data[0][0]?.toString().trim() || '';
              if (anaGrupAdi) {
                anaGruplar.push(anaGrupAdi);
              }
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }

      return anaGruplar;
    } catch (e) {
      throw new Error(`Ana gruplar yükleme hatası: ${e}`);
    }
  }

  static async getAvailableDates(): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'maddeleraylik.csv'
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        throw new Error('maddeleraylik.csv dosyası boş');
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      const dates: string[] = [];
      for (let i = 2; i < headerRow.length; i++) {
        const date = headerRow[i]?.toString().trim() || '';
        if (date && date.includes('-')) {
          dates.push(date);
        }
      }

      return dates.reverse(); // En yeni tarih önce
    } catch (e) {
      throw new Error(`Tarihler yükleme hatası: ${e}`);
    }
  }

  static async loadMaddeler(selectedAnaGrup: string): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('urunler.csv');

      const lines = csvData.split(/\r?\n/);
      const rows: any[][] = [];

      for (const line of lines) {
        if (line.trim()) {
          try {
            const parsed = Papa.parse(line, {
              header: false,
              skipEmptyLines: true,
            });
            if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
              rows.push(parsed.data[0] as any[]);
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }

      const maddeler = new Set<string>();
      const selectedGroupNorm = selectedAnaGrup.trim().toLowerCase();

      for (let i = 1; i < rows.length; i++) {
        if (rows[i].length >= 6) {
          const anaGrup = rows[i][5]?.toString().trim().toLowerCase() || '';
          const madde = rows[i][1]?.toString().trim().toLowerCase() || '';

          if (anaGrup === selectedGroupNorm && madde) {
            maddeler.add(madde);
          }
        }
      }

      return Array.from(maddeler);
    } catch (e) {
      throw new Error(`Maddeler yükleme hatası: ${e}`);
    }
  }

  static async loadMaddeDegiisimOranlari(
    maddeler: string[],
    selectedDate: string
  ): Promise<MaddeData[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'maddeleraylik.csv'
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        throw new Error('maddeleraylik.csv dosyası boş');
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      let dateColumnIndex = -1;
      for (let i = 0; i < headerRow.length; i++) {
        if (headerRow[i]?.toString().trim() === selectedDate) {
          dateColumnIndex = i;
          break;
        }
      }

      if (dateColumnIndex === -1) {
        throw new Error(`Seçilen tarih bulunamadı: ${selectedDate}`);
      }

      const maddeDataList: MaddeData[] = [];

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
              parsed.data[0].length > dateColumnIndex
            ) {
              const row = parsed.data[0] as any[];
              const rowMaddeName = row[1]?.toString().trim().toLowerCase() || '';

              if (maddeler.includes(rowMaddeName)) {
                const changeRate =
                  parseFloat(row[dateColumnIndex]?.toString() || '0') || 0.0;

                maddeDataList.push({
                  maddeName: row[1]?.toString().trim() || '', // Orijinal case'i koru
                  changeRate: changeRate,
                });
              }
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }

      maddeDataList.sort((a, b) => b.changeRate - a.changeRate);
      return maddeDataList;
    } catch (e) {
      throw new Error(`Madde değişim oranları yükleme hatası: ${e}`);
    }
  }

  static async getMaddeMonthlyChangeData(maddeAdi: string): Promise<{
    dates: string[];
    values: number[];
  }> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'maddeleraylik.csv'
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        return {dates: [], values: []};
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      // Tarihleri başlık satırından al (3. kolondan itibaren)
      const dates: string[] = [];
      for (let i = 2; i < headerRow.length; i++) {
        const tarihStr = headerRow[i]?.toString().trim() || '';
        if (tarihStr && tarihStr.includes('-')) {
          try {
            const dateParts = tarihStr.split('-');
            if (dateParts.length === 3) {
              const monthName = MONTH_NAMES[dateParts[1]] || dateParts[1];
              dates.push(`${monthName} ${dateParts[0]}`);
            } else {
              dates.push(tarihStr);
            }
          } catch (e) {
            dates.push(tarihStr);
          }
        }
      }

      // Madde adını normalize et
      const normalizedMaddeAdi = maddeAdi.trim().toLowerCase();

      // Veri satırlarında maddeyi bul
      const values: number[] = [];
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;
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
            const rowMaddeName = row[1]?.toString().trim().toLowerCase() || '';

            if (rowMaddeName === normalizedMaddeAdi) {
              // Aylık değişim değerlerini oku (3. kolondan itibaren)
              for (let j = 2; j < row.length && j <= dates.length + 1; j++) {
                const value = parseFloat(row[j]?.toString() || '0') || 0.0;
                values.push(value);
              }
              break; // Madde bulundu, döngüden çık
            }
          }
        } catch (e) {
          // Skip parse errors
          continue;
        }
      }

      return {dates: dates, values: values};
    } catch (e) {
      console.log('Madde aylık değişim veri yükleme hatası:', e);
      return {dates: [], values: []};
    }
  }

  static async getMaddeYearlyChange(maddeAdi: string): Promise<number> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'maddeleryıllık.csv',
        false // Cache'i devre dışı bırak
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        return 0.0;
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      // Madde adını normalize et
      const normalizedMaddeAdi = maddeAdi.trim().toLowerCase();

      // Header'dan madde kolonunu bul
      let maddeColumnIndex = -1;
      for (let i = 1; i < headerRow.length; i++) {
        const headerName = headerRow[i]?.toString().trim().toLowerCase() || '';
        if (headerName === normalizedMaddeAdi) {
          maddeColumnIndex = i;
          break;
        }
      }

      if (maddeColumnIndex === -1) {
        console.log(`Madde bulunamadı: ${maddeAdi}`);
        return 0.0;
      }

      // Son satırdan (en son tarih) değeri oku
      for (let i = lines.length - 1; i >= 1; i--) {
        const line = lines[i].trim();
        if (!line) continue;
        
        try {
          const parsed = Papa.parse(line, {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            parsed.data[0].length > maddeColumnIndex
          ) {
            const row = parsed.data[0] as any[];
            const value = parseFloat(row[maddeColumnIndex]?.toString() || '0');
            
            // Eğer değer geçerli bir sayıysa döndür
            if (!isNaN(value) && isFinite(value)) {
              return value;
            }
          }
        } catch (e) {
          // Skip parse errors
          continue;
        }
      }

      return 0.0;
    } catch (e) {
      console.log('Madde yıllık değişim okuma hatası:', e);
      return 0.0;
    }
  }
}

const MONTH_NAMES: {[key: string]: string} = {
  '01': 'Oca',
  '02': 'Şub',
  '03': 'Mar',
  '04': 'Nis',
  '05': 'May',
  '06': 'Haz',
  '07': 'Tem',
  '08': 'Ağu',
  '09': 'Eyl',
  '10': 'Eki',
  '11': 'Kas',
  '12': 'Ara',
};

