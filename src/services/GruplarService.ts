import Papa from 'papaparse';
import {GitHubCSVService} from './GitHubCSVService';

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

export class GruplarService {
  // Grup adlarını karşılaştırırken daha esnek eşleştirme için normalizasyon
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
  static async loadGruplarData(): Promise<{
    data: {[key: string]: number[]};
    dates: string[];
    grupNames: string[];
  }> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplarv2.csv',
        false
      );

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

      if (rows.length === 0) {
        return {data: {}, dates: [], grupNames: []};
      }

      const gruplarData: {[key: string]: number[]} = {};
      const dates: string[] = [];

      // Yeni format: ilk satır grup adları, ilk sütun boş
      const headerRow = rows[0];
      const grupNames: string[] = [];

      for (let col = 1; col < headerRow.length; col++) {
        const grupAdi = headerRow[col]?.toString().trim() || '';
        if (grupAdi) {
          grupNames.push(grupAdi);
          gruplarData[grupAdi] = [];
        }
      }

      // Satırlar: 0. sütun tarih (YYYY-MM-DD), devamında her grup için endeks
      for (let i = 1; i < rows.length; i++) {
        const row = rows[i];
        if (!row || row.length === 0) continue;

        const tarihStr = row[0]?.toString().trim() || '';
        if (!tarihStr) continue;

        // Tarihi dd.MM.yyyy formatına çevir
        try {
          const dateParts = tarihStr.split('-');
          if (dateParts.length === 3) {
            const formattedDate = `${dateParts[2]}.${dateParts[1]}.${dateParts[0]}`;
            dates.push(formattedDate);
          } else {
            dates.push(tarihStr);
          }
        } catch (e) {
          dates.push(tarihStr);
        }

        // Her grup için ilgili kolondan değeri oku
        for (let col = 1; col < headerRow.length; col++) {
          const grupAdi = headerRow[col]?.toString().trim() || '';
          if (!grupAdi || !(grupAdi in gruplarData)) continue;

          try {
            const raw = row[col]?.toString() || '';
            const indexValue = parseFloat(raw || '0');
            if (Number.isFinite(indexValue)) {
              gruplarData[grupAdi].push(indexValue);
            } else {
              // Geçersiz ise önceki değeri veya 100 kullan
              const arr = gruplarData[grupAdi];
              arr.push(arr.length > 0 ? arr[arr.length - 1] : 100.0);
            }
          } catch (e) {
            const arr = gruplarData[grupAdi];
            arr.push(arr.length > 0 ? arr[arr.length - 1] : 100.0);
          }
        }
      }

      return {
        data: gruplarData,
        dates: dates,
        grupNames: grupNames,
      };
    } catch (e) {
      console.log('Grup verileri yüklenirken hata:', e);
      return {data: {}, dates: [], grupNames: []};
    }
  }

  static async loadGruplarAylikData(): Promise<{
    data: {[key: string]: number[]};
    dates: string[];
    grupNames: string[];
  }> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaraylıkv2.csv',
        false
      );

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

      if (rows.length === 0) {
        return {data: {}, dates: [], grupNames: []};
      }

      const gruplarData: {[key: string]: number[]} = {};
      const dates: string[] = [];
      const grupNames: string[] = [];

      // Başlık satırından aylık tarihleri al ve formatla
      for (let i = 2; i < rows[0].length; i++) {
        const tarihStr = rows[0][i]?.toString() || '';
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

      // Her ana grup için aylık değişim oranlarını doğrudan oku (Web TÜFE dahil)
      for (let i = 1; i < rows.length; i++) {
        if (rows[i].length >= 3) {
          const grupAdi = rows[i][1]?.toString().trim() || '';
          if (grupAdi) {
            grupNames.push(grupAdi);
            gruplarData[grupAdi] = [];

            // Aylık değişim oranlarını doğrudan al
            for (
              let j = 2;
              j < rows[i].length && j <= dates.length + 1;
              j++
            ) {
              try {
                const changeRate =
                  parseFloat(rows[i][j]?.toString() || '0') || 0;
                gruplarData[grupAdi].push(changeRate);
              } catch (e) {
                // Geçersiz değer için 0 kullan
                gruplarData[grupAdi].push(0.0);
              }
            }
          }
        }
      }

      return {
        data: gruplarData,
        dates: dates,
        grupNames: grupNames,
      };
    } catch (e) {
      console.log('Aylık grup verileri yüklenirken hata:', e);
      return {data: {}, dates: [], grupNames: []};
    }
  }

  static async getGrupNames(): Promise<string[]> {
    try {
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplarv2.csv',
        false
      );

      const lines = csvData.split(/\r?\n/);
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const parsed = Papa.parse(line, {
            header: false,
            skipEmptyLines: true,
          });
          if (parsed.data.length === 0 || !Array.isArray(parsed.data[0])) {
            continue;
          }
          const headerRow = parsed.data[0] as any[];
          const grupNames: string[] = [];
          for (let col = 1; col < headerRow.length; col++) {
            const grupAdi = headerRow[col]?.toString().trim() || '';
            if (grupAdi) {
              grupNames.push(grupAdi);
            }
          }
          return grupNames;
        } catch (e) {
          // bir sonraki satırı dene
          continue;
        }
      }

      return [];
    } catch (e) {
      console.log('Grup adları yüklenirken hata:', e);
      return [];
    }
  }

  static async getGrupIndexData(grupAdi: string): Promise<number[]> {
    try {
      const data = await this.loadGruplarData();
      const gruplarData = data.data;
      return gruplarData[grupAdi] || [];
    } catch (e) {
      console.log('Grup endeks verisi yüklenirken hata:', e);
      return [];
    }
  }

  static async getGrupMonthlyChangeData(grupAdi: string): Promise<number[]> {
    try {
      const data = await this.loadGruplarAylikData();
      const gruplarData = data.data;
      return gruplarData[grupAdi] || [];
    } catch (e) {
      console.log('Grup aylık değişim verisi yüklenirken hata:', e);
      return [];
    }
  }

  static async getIndexDates(): Promise<string[]> {
    try {
      const data = await this.loadGruplarData();
      return data.dates;
    } catch (e) {
      console.log('Endeks tarihleri yüklenirken hata:', e);
      return [];
    }
  }

  static async getMonthlyDates(): Promise<string[]> {
    try {
      const data = await this.loadGruplarAylikData();
      return data.dates;
    } catch (e) {
      console.log('Aylık tarihler yüklenirken hata:', e);
      return [];
    }
  }

  /**
   * Yıllık CSV'den son değeri okur (yıllık değişim için)
   * @param grupAdi Grup adı (örn: 'Alkollü içecekler ve tütün')
   * @returns Yıllık değişim değeri (son satırdaki değer)
   */
  static async getYearlyChange(grupAdi: string): Promise<number> {
    try {
      // 1) Kolon indeksini her zaman referans dosya olan gruplarv2.csv'den al
      const gruplarCsv = await GitHubCSVService.loadCSVFromGitHub(
        'gruplarv2.csv',
        false,
      );
      const gruplarLines = gruplarCsv.split(/\r?\n/).filter(line => line.trim());
      if (gruplarLines.length === 0) {
        console.log('gruplarv2.csv boş veya okunamadı');
        return 0.0;
      }

      const gruplarHeaderParsed = Papa.parse(gruplarLines[0], {
        header: false,
        skipEmptyLines: true,
      });

      if (
        gruplarHeaderParsed.data.length === 0 ||
        !Array.isArray(gruplarHeaderParsed.data[0])
      ) {
        console.log('gruplarv2.csv header parse edilemedi');
        return 0.0;
      }

      const gruplarHeaderRow = gruplarHeaderParsed.data[0] as any[];

      // gruplarv2.csv içindeki kolon sırasına göre grup index'ini bul
      const targetNorm = this.normalizeKey(grupAdi);
      let columnIndex = -1;
      for (let i = 0; i < gruplarHeaderRow.length; i++) {
        const headerName = gruplarHeaderRow[i]?.toString() ?? '';
        const normalizedHeader = this.normalizeKey(headerName);
        if (normalizedHeader === targetNorm) {
          columnIndex = i;
          break;
        }
      }

      if (columnIndex === -1) {
        console.log(`gruplarv2.csv'de grup bulunamadı: ${grupAdi}`);
        return 0.0;
      }

      // 2) Aynı kolon index'ini kullanarak yıllık değişimi gruplaryıllık.csv'den oku
      //    Cache kullanma ki son güncel değer her zaman okunsun
      const csvData = await GitHubCSVService.loadCSVFromGitHub(
        'gruplaryıllık.csv',
        false,
      );
      const lines = csvData.split(/\r?\n/).filter(line => line.trim());
      
      if (lines.length < 2) {
        console.log('gruplaryıllık.csv dosyası yeterli veri içermiyor');
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
        console.log('gruplaryıllık.csv dosyasında geçerli veri satırı bulunamadı');
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
      
      console.log(`gruplaryıllık.csv'den değer okunamadı: ${grupAdi}`);
      return 0.0;
    } catch (e) {
      console.log(`Yıllık değişim okuma hatası (${grupAdi}):`, e);
      return 0.0;
    }
  }
}

