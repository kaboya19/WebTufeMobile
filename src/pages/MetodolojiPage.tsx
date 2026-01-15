import React, {useEffect, useState} from 'react';
import {View, Text, StyleSheet, ScrollView, TouchableOpacity, Linking, Platform, Alert} from 'react-native';
import {MaterialIcons as Icon} from '@expo/vector-icons';
import {Asset} from 'expo-asset';
import * as Sharing from 'expo-sharing';

type ListItem = {title: string; body?: string; bullets?: string[]};

const PDF_WEB_URL = 'https://www.webtufe.com/metodoloji';

const highlights = [
  'Günlük güncelleme: 1M+ fiyat verisi',
  'Erken uyarı: Aylık TÜFE açıklanmadan sinyal',
  'Detaylı analiz: Ana grup, harcama grubu, madde',
  'Açık erişim: Veriler ücretsiz',
];

const dataPlatforms = [
  'Migros, Carrefour, A101, BİM, ŞOK (online)',
  'Trendyol, Akakçe, Cimri',
  'Sektörel e-ticaret (elektronik, giyim, mobilya vb.)',
  'Kamu/belediye siteleri (EPDK, KGM, büyükşehir)',
  'Hizmet siteleri (Armut, Obilet, Enuygun vb.)',
];

const methodologySteps: ListItem[] = [
  {
    title: '1) Veri toplama ve temizleme',
    body: 'Her gün 05:00-08:00 arasında web scraping ile fiyatlar toplanır.',
    bullets: [
      'Platform taraması: 50+ site otomatik gezilir.',
      'Ürün eşleştirme: Barkod/marka/özellik ile birleştirme.',
      'Fiyat kaydetme: Tarih, saat, platform, fiyat saklanır.',
      'Anlık işleme: Endeks hesaplamasına alınır.',
      'Aykırı değer tespiti, platform karşılaştırması, stok kontrolü, kritik gruplar için manuel doğrulama.',
      'Sürekli kalite izleme, TÜİK ile kıyas; ortalama hata payı ±0.4 puan.',
    ],
  },
  {
    title: '2) Ürün kategorilendirmesi',
    body: 'TÜİK TÜFE sepeti ile uyumlu sınıflandırma yapılır.',
    bullets: [
      'Gıda ve alkolsüz içecekler, giyim ve ayakkabı, konut, mobilya/ev eşyası, sağlık, ulaştırma, eğlence ve kültür, çeşitli mal ve hizmetler, haberleşme, eğitim, lokanta/oteller, alkollü içecekler-tütün.',
    ],
  },
  {
    title: '3) Ağırlıklandırma',
    body: '337 madde için TÜİK ağırlıkları normalize edilerek toplam 100 olacak şekilde kullanılır.',
    bullets: [
      'Örnek: Gıda ~%28, konut ~%16, ulaştırma ~%13, lokanta/oteller ~%9, ev eşyası ~%8, giyim ~%8, diğer gruplar kalan pay.',
    ],
  },
  {
    title: '4) Endeks hesaplaması (Zincirleme Laspeyres)',
    bullets: [
      'Günlük: Fiyatlar bir önceki güne göre; madde bazında geometrik ortalama; It = It-1 × Gmadde.',
      'Yıllık: Ağırlıklar Ocak’ta güncellenir; zincirleme ile seri kesintisiz sürer.',
      'Zincirleme adımları: eski ağırlıkla son gün, yeni ağırlıkla son gün, yeni ağırlıkla ilk gün → yüzde değişimi eski seriye uygula.',
      'Geometrik ortalama aykırı değer etkisini azaltır.',
    ],
  },
];

const updateNotes: ListItem[] = [
  {title: 'Baz dönem', body: '31 Aralık 2024 = 100 (referans).'},
  {
    title: 'Güncelleme periyodu',
    bullets: [
      'Ağırlıklar: yılda 1 (Ocak).',
      'Ürün listesi: yılda 1 gözden geçirme.',
      'Endeks verisi: günde 1 kez güncellenir.',
    ],
  },
  {
    title: 'Önemli not',
    body: 'Ağırlık güncellemeleri geriye dönük uygulanmaz; seri tutarlılığı korunur.',
  },
];

const comparison = [
  {label: 'Güncelleme sıklığı', web: 'Günlük', tuik: 'Aylık'},
  {label: 'Veri kaynağı', web: 'Online fiyatlar', tuik: 'Fiziksel + online + barkod'},
  {label: 'Kapsam', web: 'E-ticaret ve büyük market zincirleri', tuik: 'Temsilî örneklem'},
  {label: 'Erişilebilirlik', web: 'Günlük, online', tuik: 'Aylık yayın'},
];

const limitations = [
  'Hizmet fiyatlarının online takibi zor; kapsam görece dar.',
  'Online fiyatlar bölgesel farklılıkları tam yansıtmayabilir.',
  'Dijital penetrasyon sınırlı demografilerde temsiliyet kısıtı.',
];

const techStack = [
  'Diller: Python (toplama/analiz), JavaScript (web arayüzü)',
  'Veritabanı: PostgreSQL',
  'Framework: Flask',
  'İşleme: Pandas, NumPy',
  'Görselleştirme: Plotly',
  'Veri güvenliği: Güvenilir kaynaklar, otomatik kontroller, şeffaflık',
];

const MetodolojiPage = () => {
  const [pdfUri, setPdfUri] = useState<string | null>(null);

  useEffect(() => {
    const loadPdf = async () => {
      try {
        const pdfModule = require('../../assets/Metodoloji.pdf');
        if (Platform.OS === 'web') {
          // Web'de require ile yüklenen asset'ler doğrudan URL döndürür
          setPdfUri(pdfModule as unknown as string);
        } else {
          // Native için Asset API kullan
          const asset = Asset.fromModule(pdfModule);
          // downloadAsync() Türkçe karakterli dosya adlarında sorun çıkarabiliyor
          try {
            await asset.downloadAsync();
            setPdfUri(asset.localUri || asset.uri || null);
          } catch (downloadError) {
            // downloadAsync hatası durumunda direkt asset.uri kullan
            setPdfUri(asset.uri || null);
          }
        }
      } catch (e) {
        console.log('Metodoloji PDF yükleme hatası:', e);
        setPdfUri(null);
      }
    };
    loadPdf();
  }, []);

  const openPdf = async () => {
    try {
      // URI yoksa asset'i tekrar resolve et
      let uri = pdfUri;
      if (!uri) {
        try {
          const pdfModule = require('../../assets/Metodoloji.pdf');
          if (Platform.OS === 'web') {
            uri = pdfModule as unknown as string;
          } else {
            const asset = Asset.fromModule(pdfModule);
            // downloadAsync() denemesi, hata durumunda asset.uri kullan
            try {
              await asset.downloadAsync();
              uri = asset.localUri || asset.uri;
            } catch (downloadError) {
              // downloadAsync hatası durumunda direkt asset.uri kullan
              uri = asset.uri;
            }
          }
        } catch (assetError) {
          console.log('Asset resolve hatası:', assetError);
        }
        
        if (!uri) {
          // Fallback: web URL'ini kullan
          uri = PDF_WEB_URL;
        }
      }

      // Web'de direkt aç
      if (Platform.OS === 'web') {
        if (typeof (global as any).window !== 'undefined' && (global as any).window.open) {
          (global as any).window.open(uri, '_blank');
        } else {
          await Linking.openURL(uri);
        }
        return;
      }

      // Mobilde PDF açmak için
      try {
        // Asset'ten gelen URI genellikle file:// ile başlar
        // Android'de direkt Linking.openURL çalışabilir
        const canOpen = await Linking.canOpenURL(uri);
        if (canOpen) {
          await Linking.openURL(uri);
        } else {
          // Fallback: Sharing ile paylaş (kullanıcı PDF viewer seçebilir)
          const isAvailable = await Sharing.isAvailableAsync();
          if (isAvailable) {
            await Sharing.shareAsync(uri, {
              mimeType: 'application/pdf',
              dialogTitle: 'Metodoloji',
            });
          } else {
            Alert.alert('Hata', 'PDF açılamadı. Lütfen tekrar deneyin.');
          }
        }
      } catch (linkError) {
        // Linking hatası durumunda Sharing dene
        try {
          const isAvailable = await Sharing.isAvailableAsync();
          if (isAvailable) {
            await Sharing.shareAsync(uri, {
              mimeType: 'application/pdf',
              dialogTitle: 'Metodoloji',
            });
          } else {
            throw linkError;
          }
        } catch (shareError) {
          throw linkError;
        }
      }
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.log('PDF açma hatası:', errorMessage);
      
      const message =
        Platform.OS === 'web'
          ? 'Tarayıcıda açılır pencere engellenmiş olabilir. Adresi manuel açmayı deneyin.'
          : `Dosya açılamadı: ${errorMessage}. Lütfen tekrar deneyin.`;
      Alert.alert('Açılamadı', message);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.hero}>
        <View style={styles.badge}>
          <Icon name="bolt" size={16} color="#0ea5e9" />
          <Text style={styles.badgeText}>Metodoloji</Text>
        </View>
        <Text style={styles.title}>Web TÜFE Metodolojisi</Text>
        <Text style={styles.subtitle}>Günlük Tüketici Fiyat Endeksi Hesaplama Yöntemi</Text>

        <View style={styles.chipsRow}>
          <Chip text="Günlük veri" />
          <Chip text="337 ürün" />
          <Chip text="Zincirleme Laspeyres" />
          <Chip text="Şeffaf & ücretsiz" />
        </View>

        <TouchableOpacity style={styles.pdfButton} onPress={openPdf}>
          <Icon name="picture-as-pdf" size={20} color="#fff" />
          <Text style={styles.pdfButtonText}>Metodoloji PDF&apos;ini Görüntüle</Text>
        </TouchableOpacity>
      </View>

      <Card title="Giriş">
        <Text style={styles.paragraph}>
          Web TÜFE, Türkiye&apos;de günlük tüketici fiyat endeksini web scraping ile toplanan
          online fiyatlara dayalı olarak üretir ve aylık TÜİK verilerine daha sık güncellenen
          bir tamamlayıcı gösterge sunar.
        </Text>
        <Text style={styles.paragraph}>
          Hızlı değişen koşullarda karar alıcıların güncel bilgi ihtiyacını karşılamak için 2025
          yılında başlatılmıştır.
        </Text>
      </Card>

      <Card title="Amaç ve Kapsam">
        <BulletList items={highlights} />
        <Text style={styles.paragraph}>
          TÜİK sepetindeki 337 ürün kategorisini izleyerek ekonominin nabzını tutar.
        </Text>
      </Card>

      <Card title="Veri Kaynakları">
        <StatRow />
        <BulletList items={dataPlatforms} />
      </Card>

      <Card title="Hesaplama Metodolojisi">
        {methodologySteps.map((item) => (
          <Section key={item.title} item={item} />
        ))}
      </Card>

      <Card title="Baz Dönem ve Güncellemeler">
        {updateNotes.map((item) => (
          <Section key={item.title} item={item} />
        ))}
      </Card>

      <Card title="TÜİK TÜFE ile Karşılaştırma">
        <View style={styles.table}>
          <View style={[styles.tableRow, styles.tableHeader]}>
            <Text style={[styles.cell, styles.cellLabel]}>Özellik</Text>
            <Text style={[styles.cell, styles.cellValue]}>Web TÜFE</Text>
            <Text style={[styles.cell, styles.cellValue]}>TÜİK TÜFE</Text>
          </View>
          {comparison.map((row) => (
            <View key={row.label} style={styles.tableRow}>
              <Text style={[styles.cell, styles.cellLabel]}>{row.label}</Text>
              <Text style={[styles.cell, styles.cellValue]}>{row.web}</Text>
              <Text style={[styles.cell, styles.cellValue]}>{row.tuik}</Text>
            </View>
          ))}
        </View>
      </Card>

      <Card title="Sınırlamalar">
        <BulletList items={limitations} />
      </Card>

      <Card title="Teknik Altyapı ve Veri Güvenliği">
        <BulletList items={techStack} />
      </Card>

      <Card title="Günlük Kümülatif Endeks Formülü">
        <View style={styles.formulaHero}>
          <Text style={styles.formulaTitle}>Madde Bazında Geometrik Ortalama</Text>
          <Text style={styles.formulaBig}>Gₘₐddₑ,ₜ = ( Πᵢ₌₁ⁿ Rᵢ,ₜ )¹/ⁿ</Text>
          <Text style={[styles.formulaTitle, {marginTop: 10}]}>Kümülatif Endeks Hesabı</Text>
          <Text style={styles.formulaBig}>Iₜ = Iₜ₋₁ × Gₘₐddₑ,ₜ</Text>
          <View style={styles.legendList}>
            {[
              'Iₜ: t gününün endeks değeri',
              'Iₜ₋₁: Bir önceki günün endeks değeri',
              'Gₘₐddₑ,ₜ: t günündeki madde bazında geometrik ortalama',
              'Rᵢ,ₜ: i. ürünün günlük fiyat değişim oranı (Pₜ / Pₜ₋₁)',
              'n: Madde içindeki ürün sayısı',
              'Π: Çarpım işareti (tüm ürünler çarpılır)',
            ].map((t, idx) => (
              <Text key={idx} style={styles.legendText}>
                {t}
              </Text>
            ))}
          </View>
          <View style={styles.infoBox}>
            <Icon name="lightbulb-outline" size={18} color="#f59e0b" />
            <Text style={styles.infoText}>
              Neden geometrik ortalama? Çarpımsal doğayı yansıtır, aykırı değerlerin etkisini
              azaltır ve günlük dalgalanmalarda daha istikrarlı sonuç verir.
            </Text>
          </View>
        </View>

        <View style={styles.stepsBox}>
          <Text style={styles.stepsTitle}>Hesaplama Adımları</Text>
          {[
            {id: '1', text: 'Günlük fiyat değişimi: Rᵢ,ₜ = Pₜ,ᵢ / Pₜ₋₁,ᵢ'},
            {id: '2', text: 'Madde bazında geometrik ortalama: Gₘₐddₑ = (Π Rᵢ)¹/ⁿ'},
            {id: '3', text: 'Kümülatif endeks: Iₜ = Iₜ₋₁ × Gₘₐddₑ'},
            {
              id: '4',
              text: 'Alt grup endeksleri: Aynı yöntem ana grup, harcama grubu ve madde endekslerine ayrı uygulanır.',
            },
          ].map((step) => (
            <View key={step.id} style={styles.stepRow}>
              <View style={styles.stepBadge}>
                <Text style={styles.stepBadgeText}>{step.id}</Text>
              </View>
              <Text style={styles.stepText}>{step.text}</Text>
            </View>
          ))}
        </View>

        <View style={styles.exampleBox}>
          <Text style={styles.exampleTitle}>Örnek (Günlük - Kümülatif)</Text>
          <Text style={styles.paragraph}>
            Senaryo: “Süt” maddesinde 3 marka (dünkü fiyat / bugünkü fiyat → R)
          </Text>
          <View style={styles.table}>
            <View style={[styles.tableRow, styles.tableHeader]}>
              <Text style={[styles.cell, styles.cellLabel]}>Marka</Text>
              <Text style={[styles.cell, styles.cellValue]}>Dün (Pₜ₋₁)</Text>
              <Text style={[styles.cell, styles.cellValue]}>Bugün (Pₜ)</Text>
              <Text style={[styles.cell, styles.cellValue]}>Değişim (R)</Text>
            </View>
            {[
              {m: 'A', p1: '50 TL', p2: '52 TL', r: '1.040'},
              {m: 'B', p1: '48 TL', p2: '49.5 TL', r: '1.031'},
              {m: 'C', p1: '55 TL', p2: '56 TL', r: '1.018'},
            ].map((row) => (
              <View key={row.m} style={styles.tableRow}>
                <Text style={[styles.cell, styles.cellLabel]}>Marka {row.m}</Text>
                <Text style={[styles.cell, styles.cellValue]}>{row.p1}</Text>
                <Text style={[styles.cell, styles.cellValue]}>{row.p2}</Text>
                <Text style={[styles.cell, styles.cellValue]}>{row.r}</Text>
              </View>
            ))}
          </View>
          <Text style={styles.paragraph}>
            Geometrik ortalama: G_süt = (1.040 × 1.031 × 1.018)^(1/3) ≈ 1.0296
          </Text>
          <Text style={styles.paragraph}>
            Kümülatif endeks: Dünkü endeks Iₜ₋₁ = 105.20 → Bugün Iₜ = 105.20 × 1.0296 ≈ 108.31
            (günlük %2.96 artış)
          </Text>
          <View style={styles.infoBox}>
            <Icon name="info-outline" size={18} color="#0ea5e9" />
            <Text style={styles.infoText}>
              Zincirleme yöntemle her gün bir önceki güne göre hesaplanır; böylece baz döneme kadar
              tüm günlük değişimler endekse yansır.
            </Text>
          </View>
        </View>
      </Card>
    </ScrollView>
  );
};

const Card: React.FC<{title: string; children: React.ReactNode}> = ({title, children}) => (
  <View style={styles.card}>
    <Text style={styles.cardTitle}>{title}</Text>
    {children}
  </View>
);

const BulletList: React.FC<{items: string[]}> = ({items}) => (
  <View style={styles.list}>
    {items.map((t, idx) => (
      <View key={idx} style={styles.listItem}>
        <Text style={styles.bullet}>{'\u2022'}</Text>
        <Text style={styles.listText}>{t}</Text>
      </View>
    ))}
  </View>
);

const Section: React.FC<{item: ListItem}> = ({item}) => (
  <View style={styles.section}>
    <Text style={styles.sectionTitle}>{item.title}</Text>
    {item.body ? <Text style={styles.paragraph}>{item.body}</Text> : null}
    {item.bullets ? <BulletList items={item.bullets} /> : null}
  </View>
);

const StatRow = () => (
  <View style={styles.statsRow}>
    <View style={styles.statBox}>
      <Text style={styles.statValue}>1M+</Text>
      <Text style={styles.statLabel}>Günlük veri</Text>
    </View>
    <View style={styles.statBox}>
      <Text style={styles.statValue}>337</Text>
      <Text style={styles.statLabel}>Ürün sayısı</Text>
    </View>
  </View>
);

const Chip: React.FC<{text: string}> = ({text}) => (
  <View style={styles.chip}>
    <Text style={styles.chipText}>{text}</Text>
  </View>
);

const styles = StyleSheet.create({
  container: {flex: 1, backgroundColor: '#f5f7fb'},
  content: {padding: 16, gap: 14},
  hero: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 12,
    shadowOffset: {width: 0, height: 6},
    elevation: 2,
    gap: 10,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(14,165,233,0.12)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: 'rgba(14,165,233,0.3)',
  },
  badgeText: {color: '#0ea5e9', fontWeight: '700', fontSize: 12},
  title: {fontSize: 26, fontWeight: '800', color: '#0f172a'},
  subtitle: {fontSize: 15, color: '#4b5563'},
  pdfButton: {
    marginTop: 8,
    backgroundColor: '#0ea5e9',
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    alignSelf: 'flex-start',
  },
  pdfButtonText: {color: '#ffffff', fontWeight: '800', fontSize: 14},
  chipsRow: {flexDirection: 'row', flexWrap: 'wrap', gap: 8},
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    gap: 10,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    shadowOffset: {width: 0, height: 4},
    elevation: 2,
  },
  cardTitle: {fontSize: 18, fontWeight: '800', color: '#0f172a'},
  paragraph: {fontSize: 14, color: '#374151', lineHeight: 20},
  list: {gap: 6},
  listItem: {flexDirection: 'row', gap: 8, alignItems: 'flex-start'},
  bullet: {fontSize: 14, color: '#0ea5e9', marginTop: 1},
  listText: {flex: 1, fontSize: 14, color: '#374151', lineHeight: 20},
  section: {gap: 4},
  sectionTitle: {fontSize: 15, fontWeight: '800', color: '#111827'},
  statsRow: {
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
  },
  statBox: {
    flex: 1,
    padding: 12,
    backgroundColor: '#e0f2fe',
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#bae6fd',
  },
  statValue: {fontSize: 18, fontWeight: '800', color: '#0369a1'},
  statLabel: {fontSize: 12, color: '#1f2937'},
  table: {
    borderWidth: 1,
    borderColor: '#e5e7eb',
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#ffffff',
  },
  tableRow: {flexDirection: 'row'},
  tableHeader: {backgroundColor: '#f1f5f9'},
  cell: {
    flex: 1,
    padding: 10,
    borderRightWidth: 1,
    borderRightColor: '#e5e7eb',
  },
  cellLabel: {flex: 1.4, fontWeight: '800', color: '#0f172a', fontSize: 13},
  cellValue: {fontSize: 13, color: '#374151'},
  chip: {
    backgroundColor: 'rgba(14,165,233,0.1)',
    borderColor: 'rgba(14,165,233,0.3)',
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 999,
  },
  chipText: {color: '#0ea5e9', fontWeight: '700', fontSize: 12},
  codeBox: {
    backgroundColor: '#0f172a',
    borderRadius: 10,
    padding: 12,
    borderWidth: 1,
    borderColor: '#1f2937',
    marginBottom: 8,
  },
  codeLine: {color: '#e5e7eb', fontFamily: 'monospace', fontSize: 13},
  infoBox: {
    flexDirection: 'row',
    gap: 8,
    alignItems: 'flex-start',
    backgroundColor: '#fff7ed',
    borderRadius: 10,
    padding: 10,
    borderWidth: 1,
    borderColor: '#ffedd5',
    marginTop: 8,
  },
  infoText: {flex: 1, color: '#92400e', fontSize: 13.5, lineHeight: 19},
  exampleBox: {
    backgroundColor: '#f8fafc',
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    gap: 8,
    marginTop: 8,
  },
  exampleTitle: {fontSize: 16, fontWeight: '800', color: '#0f172a'},
  stepsBox: {
    backgroundColor: '#fff7ed',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#ffedd5',
    padding: 12,
    gap: 6,
    marginTop: 10,
  },
  stepsTitle: {fontSize: 16, fontWeight: '800', color: '#92400e', marginBottom: 4},
  stepRow: {flexDirection: 'row', gap: 10, marginBottom: 6, alignItems: 'center'},
  stepBadge: {
    minWidth: 28,
    height: 28,
    paddingHorizontal: 6,
    borderRadius: 14,
    backgroundColor: '#f97316',
    justifyContent: 'center',
    alignItems: 'center',
  },
  stepBadgeText: {color: '#fff', fontWeight: '800'},
  stepText: {flex: 1, color: '#1f2937', fontSize: 14, lineHeight: 20},
  formulaHero: {
    backgroundColor: '#0f172a',
    borderRadius: 12,
    padding: 14,
    gap: 8,
    borderWidth: 1,
    borderColor: '#1f2937',
  },
  formulaTitle: {color: '#cbd5e1', fontSize: 14, fontWeight: '700'},
  formulaBig: {color: '#ffffff', fontSize: 20, fontWeight: '800', fontFamily: 'monospace'},
  legendList: {gap: 4},
  legendText: {color: '#cbd5e1', fontSize: 13},
});

export default MetodolojiPage;


