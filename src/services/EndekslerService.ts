import Papa from 'papaparse';
import {GitHubCSVService} from './GitHubCSVService';

export class EndekslerService {
  static async loadEndekslerData(): Promise<{
    data: {[key: string]: number[]};
    dates: string[];
  }> {
    const data = await GitHubCSVService.loadCSVFromGitHub('endeksler.csv', true);

    const lines = data.split(/\r?\n/);
    const csvData: any[][] = [];

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine) {
        try {
          const parsed = Papa.parse(trimmedLine, {
            header: false,
            skipEmptyLines: true,
          });
          if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
            csvData.push(parsed.data[0] as any[]);
          }
        } catch (e) {
          // Parse hatalarını sessizce atla
        }
      }
    }

    const endeksData: {[key: string]: number[]} = {};
    const dates: string[] = [];
    const endeksNames: string[] = [];

    if (csvData.length > 0) {
      // First row contains endeks names (columns)
      const headers = csvData[0];

      // Extract endeks names from headers (skip first empty column)
      for (let i = 1; i < headers.length; i++) {
        const endeksName = headers[i]?.toString().trim() || '';
        if (endeksName) {
          endeksNames.push(endeksName);
          endeksData[endeksName] = [];
        }
      }

      // Process data rows (each row is a date)
      for (let i = 1; i < csvData.length; i++) {
        const row = csvData[i];
        if (row && row.length > 0) {
          // First column is the date
          const dateStr = row[0]?.toString().trim() || '';
          if (dateStr) {
            // Convert date format from 2025-01-01 to 01.01.2025
            try {
              const dateParts = dateStr.split('-');
              if (dateParts.length === 3) {
                const formattedDate = `${dateParts[2]}.${dateParts[1]}.${dateParts[0]}`;
                dates.push(formattedDate);
              } else {
                dates.push(dateStr);
              }
            } catch (e) {
              dates.push(dateStr);
            }

            // Parse values for each endeks (skip first column which is the date)
            for (let j = 1; j < row.length && j <= endeksNames.length; j++) {
              const endeksName = endeksNames[j - 1];
              try {
                const value = parseFloat(row[j]?.toString().trim() || '0') || 0;
                endeksData[endeksName]?.push(value);
              } catch (e) {
                endeksData[endeksName]?.push(100.0); // Default value for parsing errors
              }
            }
          }
        }
      }
    }

    return {
      data: endeksData,
      dates: dates,
    };
  }

  static async getEndeksList(): Promise<string[]> {
    const data = await this.loadEndekslerData();
    const endeksData = data.data;
    const endeksList = Object.keys(endeksData).sort();

    // Add Web TÜFE as the first option
    endeksList.unshift('Web TÜFE');

    return endeksList;
  }

  static async loadTufeData(): Promise<{
    data: {[key: string]: number[]};
    dates: string[];
  }> {
    const data = await GitHubCSVService.loadCSVFromGitHub('tufe.csv', true);

    const lines = data.split(/\r?\n/);
    const csvData: any[][] = [];

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine) {
        try {
          const parsed = Papa.parse(trimmedLine, {
            header: false,
            skipEmptyLines: true,
          });
          if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
            csvData.push(parsed.data[0] as any[]);
          }
        } catch (e) {
          // Parse hatalarını sessizce atla
        }
      }
    }

    const tufeValues: number[] = [];
    const dates: string[] = [];

    if (csvData.length > 0) {
      // Process data rows (skip header)
      for (let i = 1; i < csvData.length; i++) {
        const row = csvData[i];
        if (row && row.length >= 2) {
          // First column is date
          const dateStr = row[0]?.toString().trim() || '';
          if (dateStr) {
            // Convert date format from 2025-01-01 to 01.01.2025
            try {
              const dateParts = dateStr.split('-');
              if (dateParts.length === 3) {
                const formattedDate = `${dateParts[2]}.${dateParts[1]}.${dateParts[0]}`;
                dates.push(formattedDate);
              } else {
                dates.push(dateStr);
              }
            } catch (e) {
              dates.push(dateStr);
            }

            // Second column is TÜFE value
            try {
              const value = parseFloat(row[1]?.toString().trim() || '0') || 0;
              tufeValues.push(value);
            } catch (e) {
              tufeValues.push(100.0);
            }
          }
        }
      }
    }

    return {
      data: {'Web TÜFE': tufeValues},
      dates: dates,
    };
  }

  /**
   * Yıllık CSV'den son değeri okur (yıllık değişim için)
   * @param endeksName Endeks adı (örn: 'Web TÜFE', 'Alkollü içecekler ve tütün')
   * @returns Yıllık değişim değeri (son satırdaki değer)
   */
  static async getYearlyChange(endeksName: string): Promise<number> {
    try {
      // Web TÜFE için tüfeyıllık.csv kullan
      if (endeksName === 'Web TÜFE') {
        const csvData = await GitHubCSVService.loadCSVFromGitHub('tüfeyıllık.csv', true);
        const lines = csvData.split(/\r?\n/).filter(line => line.trim());
        
        if (lines.length < 2) {
          console.log('tüfeyıllık.csv dosyası yeterli veri içermiyor');
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
          console.log('tüfeyıllık.csv dosyasında geçerli veri satırı bulunamadı');
          return 0.0;
        }
        
        const parsed = Papa.parse(lastLine, {
          header: false,
          skipEmptyLines: true,
        });
        
        if (parsed.data.length > 0 && Array.isArray(parsed.data[0])) {
          const row = parsed.data[0] as any[];
          // İkinci sütun Web TÜFE yıllık değişim değeri (ilk sütun tarih)
          if (row.length >= 2) {
            const valueStr = row[1]?.toString().trim() || '';
            if (valueStr) {
              const value = parseFloat(valueStr);
              if (!isNaN(value)) {
                return value;
              }
            }
          }
        }
        
        console.log('tüfeyıllık.csv dosyasından değer okunamadı');
        return 0.0;
      }
      
      // Diğer endeksler için endeksler.csv'den son değeri al
      // (Bu durumda yıllık CSV yok, mevcut mantığı kullan)
      const data = await this.loadEndekslerData();
      const values = data.data[endeksName];
      if (values && values.length > 0) {
        return values[values.length - 1] - 100.0;
      }
      
      return 0.0;
    } catch (e) {
      console.log(`Yıllık değişim okuma hatası (${endeksName}):`, e);
      return 0.0;
    }
  }
}

