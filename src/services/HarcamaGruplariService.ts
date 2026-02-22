import Papa from 'papaparse';
import {GitHubCSVService} from './GitHubCSVService';
import {
  AnaGrupData,
  HarcamaGrubuData,
  HarcamaGrubuEndeksData,
  HarcamaGrubuAylikData,
  HarcamaGrubuIstatistik,
} from '../models/HarcamaGrubuData';

export class HarcamaGruplariService {
  private static normalizeKey(s: string): string {
    return (s || '')
      .toLowerCase()
      .trim()
      .replace(/\u00a0/g, ' ')
      .replace(/\s+/g, ' ')
      .replace(/[’'"]/g, '')
      .replace(/[(),.]/g, '')
      .replace(/ğ/g, 'g')
      .replace(/ü/g, 'u')
      .replace(/ş/g, 's')
      .replace(/ı/g, 'i')
      .replace(/ö/g, 'o')
      .replace(/ç/g, 'c');
  }

  private static tokenize(s: string): string[] {
    const norm = this.normalizeKey(s);
    if (!norm) return [];
    return norm.split(' ').filter(Boolean);
  }

  private static jaccardSimilarity(aTokens: string[], bTokens: string[]): number {
    if (aTokens.length === 0 || bTokens.length === 0) return 0;
    const a = new Set(aTokens);
    const b = new Set(bTokens);
    let inter = 0;
    for (const t of a) {
      if (b.has(t)) inter++;
    }
    const union = a.size + b.size - inter;
    return union === 0 ? 0 : inter / union;
  }

  private static findColumnIndex(headerRow: any[], columnName: string): number {
    const target = this.normalizeKey(columnName);
    // direct match
    for (let i = 0; i < headerRow.length; i++) {
      const h = this.normalizeKey(headerRow[i]?.toString() || '');
      if (h === target) return i;
    }
    // fuzzy contains
    for (let i = 0; i < headerRow.length; i++) {
      const h = this.normalizeKey(headerRow[i]?.toString() || '');
      if (h && (h.includes(target) || target.includes(h))) return i;
    }
    // token similarity (handles minor typos like "vi ki" vs "viski")
    const targetTokens = this.tokenize(columnName);
    let bestIdx = -1;
    let bestScore = 0;
    for (let i = 0; i < headerRow.length; i++) {
      const hRaw = headerRow[i]?.toString() || '';
      const score = this.jaccardSimilarity(targetTokens, this.tokenize(hRaw));
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    if (bestIdx !== -1 && bestScore >= 0.6) return bestIdx;
    return -1;
  }

  static async loadAnaGruplar(): Promise<AnaGrupData[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('gruplar.csv');

      const lines = csvData.split(/\r?\n/);
      const anaGruplar: AnaGrupData[] = [];

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
                anaGruplar.push({name: anaGrupAdi});
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

  static async loadHarcamaGruplari(
    selectedAnaGrup: string
  ): Promise<string[]> {
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

      const harcamaGruplari = new Set<string>();
      const selectedGroupNorm = selectedAnaGrup.trim().toLowerCase();

      for (let i = 1; i < rows.length; i++) {
        if (rows[i].length >= 6) {
          const anaGrup = rows[i][5]?.toString().trim().toLowerCase() || '';
          const grup = rows[i][2]?.toString().trim() || '';

          if (anaGrup === selectedGroupNorm && grup) {
            harcamaGruplari.add(grup);
          }
        }
      }

      return Array.from(harcamaGruplari);
    } catch (e) {
      throw new Error(`Harcama grupları yükleme hatası: ${e}`);
    }
  }

  static async loadHarcamaGrubuDegiisimOranlari(
    harcamaGruplari: string[],
    selectedDate: string
  ): Promise<HarcamaGrubuData[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'harcama_gruplarıaylık.csv'
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        throw new Error('harcama_gruplarıaylık.csv dosyası boş');
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

      const normalizedHarcamaGruplari = new Set(
        harcamaGruplari.map((grup) => grup.trim().toLowerCase())
      );
      const result: HarcamaGrubuData[] = [];

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
              const grupAdi = row[1]?.toString().trim() || '';
              const normalizedGrupAdi = grupAdi.toLowerCase();

              if (normalizedHarcamaGruplari.has(normalizedGrupAdi)) {
                const changeRate =
                  parseFloat(row[dateColumnIndex]?.toString() || '0') || 0.0;
                result.push({
                  groupName: grupAdi,
                  changeRate: changeRate,
                });
              }
            }
          } catch (e) {
            // Skip parse errors
          }
        }
      }

      result.sort((a, b) => b.changeRate - a.changeRate);
      return result;
    } catch (e) {
      throw new Error(`Harcama grubu değişim oranları yükleme hatası: ${e}`);
    }
  }

  static async getAvailableDates(): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'harcama_gruplarıaylık.csv'
      );

      const lines = csvData.split(/\r?\n/);
      if (lines.length === 0) {
        throw new Error('harcama_gruplarıaylık.csv dosyası boş');
      }

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headers =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      const dates: string[] = [];
      for (let i = 2; i < headers.length; i++) {
        const date = headers[i]?.toString().trim() || '';
        if (date) {
          dates.push(date);
        }
      }

      return dates;
    } catch (e) {
      throw new Error(`Tarihler yükleme hatası: ${e}`);
    }
  }

  static async loadHarcamaGrubuEndeksData(
    selectedGrup: string
  ): Promise<HarcamaGrubuEndeksData[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('harcama_grupları.csv');
      const lines = csvData.split(/\r?\n/).filter((l) => l.trim().length > 0);
      if (lines.length === 0) return [];

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      const colIndex = this.findColumnIndex(headerRow, selectedGrup);
      if (colIndex === -1) return [];

      const result: HarcamaGrubuEndeksData[] = [];

      for (let i = 1; i < lines.length; i++) {
        try {
          const parsed = Papa.parse(lines[i], {
            header: false,
            skipEmptyLines: true,
          });
          if (parsed.data.length === 0 || !Array.isArray(parsed.data[0])) continue;
          const row = parsed.data[0] as any[];
          if (row.length <= colIndex) continue;

          const tarih = row[0]?.toString().trim() || '';
          const v = parseFloat(row[colIndex]?.toString() || '0');
          if (!tarih || !Number.isFinite(v)) continue;

          result.push({tarih, endeks: v});
        } catch (e) {
          // skip row
        }
      }

      return result;
    } catch (e) {
      throw new Error(`Harcama grubu endeks verisi yükleme hatası: ${e}`);
    }
  }

  static async loadHarcamaGrubuAylikData(
    selectedGrup: string
  ): Promise<HarcamaGrubuAylikData[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub('harcama_gruplarıaylık.csv');
      const lines = csvData.split(/\r?\n/).filter((l) => l.trim().length > 0);
      if (lines.length === 0) return [];

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      // dates start at col 2: [, Grup, YYYY-MM-DD, ...]
      const dates: string[] = [];
      for (let i = 2; i < headerRow.length; i++) {
        const d = headerRow[i]?.toString().trim() || '';
        if (d) dates.push(d);
      }

      const target = this.normalizeKey(selectedGrup);
      let matchedRow: any[] | null = null;
      let bestRow: any[] | null = null;
      let bestScore = 0;
      const targetTokens = this.tokenize(selectedGrup);

      for (let i = 1; i < lines.length; i++) {
        try {
          const parsed = Papa.parse(lines[i], {
            header: false,
            skipEmptyLines: true,
          });
          if (parsed.data.length === 0 || !Array.isArray(parsed.data[0])) continue;
          const row = parsed.data[0] as any[];
          if (row.length < 3) continue;
          const grupAdi = row[1]?.toString().trim() || '';
          if (this.normalizeKey(grupAdi) === target) {
            matchedRow = row;
            break;
          }
          const score = this.jaccardSimilarity(targetTokens, this.tokenize(grupAdi));
          if (score > bestScore) {
            bestScore = score;
            bestRow = row;
          }
        } catch (e) {
          // skip row
        }
      }

      if (!matchedRow && bestRow && bestScore >= 0.6) matchedRow = bestRow;
      if (!matchedRow) return [];

      const result: HarcamaGrubuAylikData[] = [];
      for (let i = 0; i < dates.length; i++) {
        const colIndex = i + 2;
        const tarih = dates[i];
        const raw = matchedRow[colIndex]?.toString() ?? '';
        const v = parseFloat(raw || '0');
        if (!tarih) continue;
        result.push({tarih, degisimOrani: Number.isFinite(v) ? v : 0});
      }

      return result;
    } catch (e) {
      throw new Error(`Harcama grubu aylık veri yükleme hatası: ${e}`);
    }
  }

  /**
   * harcamagruplarıyıllık.csv'den seçili harcama grubu için yıllık değişimi okur.
   * Son (en güncel) değeri döndürür.
   */
  static async getHarcamaGrubuYillikDegisim(
    selectedGrup: string
  ): Promise<number> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'harcamagruplarıyıllık.csv'
      );

      const lines = csvData.split(/\r?\n/).filter((l) => l.trim().length > 0);
      if (lines.length < 2) return 0.0;

      const parsedHeader = Papa.parse(lines[0], {
        header: false,
        skipEmptyLines: true,
      });
      const headerRow =
        parsedHeader.data.length > 0 && Array.isArray(parsedHeader.data[0])
          ? (parsedHeader.data[0] as any[])
          : [];

      const colIndex = this.findColumnIndex(headerRow, selectedGrup);
      if (colIndex < 0 || colIndex >= headerRow.length) return 0.0;

      for (let i = lines.length - 1; i >= 1; i--) {
        try {
          const parsed = Papa.parse(lines[i], {
            header: false,
            skipEmptyLines: true,
          });
          if (
            parsed.data.length > 0 &&
            Array.isArray(parsed.data[0]) &&
            (parsed.data[0] as any[]).length > colIndex
          ) {
            const row = parsed.data[0] as any[];
            const val = parseFloat(row[colIndex]?.toString() || '');
            if (Number.isFinite(val)) return val;
          }
        } catch {
          continue;
        }
      }
      return 0.0;
    } catch (e) {
      throw new Error(`Yıllık değişim okuma hatası: ${e}`);
    }
  }

  static async calculateHarcamaGrubuStatistics(
    selectedGrup: string
  ): Promise<HarcamaGrubuIstatistik> {
    try {
      const [yillikDegisim, aylik] = await Promise.all([
        this.getHarcamaGrubuYillikDegisim(selectedGrup),
        this.loadHarcamaGrubuAylikData(selectedGrup),
      ]);

      const lastAylik = aylik.length > 0 ? aylik[aylik.length - 1].degisimOrani : 0.0;

      return {
        yillikDegisim,
        aylikDegisim: Number.isFinite(lastAylik) ? lastAylik : 0.0,
        selectedGrup,
      };
    } catch (e) {
      throw new Error(`Harcama grubu istatistik hesaplama hatası: ${e}`);
    }
  }
}

