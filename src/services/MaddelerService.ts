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
}

