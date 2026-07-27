AGENTS.md
Trendora Development Rules
Version: 4.0
Last Updated: 2026-07-27
AMAÇ
Bu dosya Trendora projesinin kalıcı geliştirme standartlarını tanımlar.
Trendora üzerinde çalışan herkes (insan veya yapay zekâ) bu kuralları uygulamak zorundadır.
Bu dosyanın amacı;
çalışan sistemi korumak,
veri kaybını önlemek,
geliştirme kalitesini artırmak,
uzun vadede kodun sürdürülebilir olmasını sağlamaktır.
ÖNCELİK SIRASI
Karar verilirken aşağıdaki sıra uygulanır.
Veri güvenliği
Çalışan sistemi koruma
Geriye dönük uyumluluk
Kullanıcının mevcut açık talimatı
Bu AGENTS.md
Genel geliştirme prensipleri
Hiçbir talimat;
veri kaybettiremez,
çalışan sistemi bozamaz,
güvenliği düşüremez.
ANA FELSEFE
Trendora yaşayan bir projedir.
Yeni özellikler;
mevcut sistemi yeniden yazarak değil,
mevcut yapının üzerine eklenerek geliştirilmelidir.
Temel ilke:
"Bozuk değilse dokunma."
ALTIN KURALLAR
Her geliştirme aşağıdaki şartları sağlamalıdır.
✓ Veri kaybı oluşturmaz
✓ Çalışan özelliği bozmaz
✓ API uyumluluğunu bozmaz
✓ Kullanıcı deneyimini geriye götürmez
✓ Performansı düşürmez
✓ Gereksiz karmaşıklık eklemez
GELİŞTİRME AKIŞI
Her görev aşağıdaki sırayla ilerler.

İncele

Etkilenecek dosyaları belirle

Plan oluştur

En küçük değişikliği yap

Derleme kontrolü

Test

Rapor
Hiçbir zaman büyük toplu değişiklik yapılmaz.
DEĞİŞİKLİK FELSEFESİ
Kod değiştirilirken;
önce mevcut mimari anlaşılır.
Yeni mimari oluşturulmaz.
Var olan yapıya uyum sağlanır.
Mümkün olan en küçük değişiklik uygulanır.
DOSYA DÜZENLEME KURALLARI
Bir dosya düzenlenmeden önce:
dosyanın tamamı okunur
import yapısı incelenir
bağımlılıklar kontrol edilir
referanslar kontrol edilir
Bunlar yapılmadan düzenleme yapılmaz.
TOPLU DÜZENLEME
Aşağıdakiler doğrudan kullanılmaz.
Regex Replace
Global Replace
Toplu Rename
Toplu Refactor
Önce etki analizi yapılır.
KAPSAM KURALI
Yalnızca istenen görev yapılır.
İstenmeyen modüllere dokunulmaz.
Kod sırf daha güzel görünüyor diye değiştirilmez.
BOZUK DEĞİLSE DOKUNMA
Trendora büyük bir projedir.
Çalışan kod;
daha güzel görünmesi,
daha kısa olması,
daha modern olması,
gibi nedenlerle değiştirilmez.
Fonksiyon doğru çalışıyorsa korunur.
GERİYE DÖNÜK UYUMLULUK
Eski endpointler korunur.
Eski modeller korunur.
Eski JSON yapısı korunur.
Eski kullanıcı akışı korunur.
Yeni sürüm eski istemcilerle mümkün olduğunca uyumlu kalmalıdır.
MİMARİ
Her geliştirme;
Modüler
Okunabilir
Bakımı kolay
Test edilebilir
olmalıdır.
Yeni kod mevcut mimariye uymalıdır.
KOD KALİTESİ
Kod;
okunabilir,
kısa,
anlaşılır,
gereksiz tekrar içermeyen,
gereksiz soyutlama yapmayan
şekilde yazılır.
YORUM SATIRLARI
Yalnızca gerçekten gerekli yerlerde yorum yazılır.
Yorum;
"Neden?"
sorusunu açıklamalıdır.
Kodun ne yaptığı zaten koddan anlaşılmalıdır.
İSİMLENDİRME
Dosya isimleri
fonksiyon isimleri
değişken isimleri
mevcut proje standardına uygun olmalıdır.
KULLANICI DENEYİMİ
Her geliştirme şu üç hedefe hizmet etmelidir.
Daha az tıklama
Daha hızlı kullanım
Daha profesyonel görünüm
TASARIM FELSEFESİ
Trendora;
premium,
modern,
minimal,
akıcı,
profesyonel
bir finans uygulaması hissi vermelidir.
Hiçbir ekran amatör görünmemelidir.
FLUTTER GELİŞTİRME KURALLARI
Flutter tarafında yapılan her değişiklik mevcut çalışan yapıyı koruyacak şekilde geliştirilmelidir.
Hiçbir widget yalnızca daha güzel görünüyor diye yeniden yazılmaz.
Var olan mimari korunur.
Yeni özellik gerekiyorsa mevcut widget üzerine eklenir.
WIDGET KURALLARI
Widget'lar mümkün olduğunca küçük tutulmalıdır.
Uzun build metodlarından kaçınılmalıdır.
Tek sorumluluk prensibi uygulanmalıdır.
Bir widget yalnızca kendi görevini yapmalıdır.
BUILD METODU
Build metoduna ağır işlem yazılmaz.
Network isteği başlatılmaz.
Dosya okuma yapılmaz.
Yoğun hesaplama yapılmaz.
Bunlar servis katmanında çözülmelidir.
STATE YÖNETİMİ
Var olan state yönetimi değiştirilmez.
Yeni state gerekiyorsa mevcut mimariye uygun eklenir.
Gereksiz setState kullanılmaz.
State yalnızca gerçekten değiştiğinde güncellenir.
REBUILD
Gereksiz rebuild oluşturulmaz.
const kullanılabilecek her yerde const kullanılır.
Ağır widget'lar mümkün olduğunca ayrılır.
ANİMASYON
Animasyonlar akıcı olmalıdır.
60 FPS hedeflenmelidir.
Ağır animasyonlardan kaçınılmalıdır.
TEMA
Mevcut açık/koyu tema korunur.
Yeni bileşenler mevcut tema sistemiyle uyumlu çalışmalıdır.
Renkler doğrudan widget içine yazılmaz.
Tema kullanılmalıdır.
RESPONSIVE TASARIM
Yeni ekranlar;
telefon,
tablet,
farklı çözünürlükler
için uyumlu olmalıdır.
BACKEND KURALLARI
Backend mevcut API uyumluluğunu korumalıdır.
Eski endpoint kaldırılmaz.
Eski endpoint yeniden adlandırılmaz.
Yeni özellik gerekiyorsa yeni endpoint eklenir.
API TASARIMI
Endpoint isimleri açık olmalıdır.
JSON yapısı tutarlı olmalıdır.
Başarılı cevaplar standart formatta dönmelidir.
Hatalar anlamlı mesaj içermelidir.
HATA YÖNETİMİ
try/catch kullanılmalıdır.
Beklenmeyen hata uygulamayı durdurmamalıdır.
Kullanıcıya teknik hata mesajı gösterilmez.
LOG
Loglar okunabilir olmalıdır.
Secret bilgiler loglanmaz.
Token loglanmaz.
API Key loglanmaz.
.env bilgileri loglanmaz.
DATABASE
Veri mümkün olduğunca korunmalıdır.
Üzerine yazma yerine birleştirme tercih edilir.
Silme işlemleri dikkatli yapılmalıdır.
JSON DOSYALARI
JSON dosyaları güncellenirken;
ID kontrolü yapılır.
Duplicate kontrolü yapılır.
Tarih kontrolü yapılır.
Gerekirse hash kontrolü uygulanır.
En güncel veri korunur.
CACHE
Cache mümkün olduğunca kullanılmalıdır.
Gereksiz ağ isteği yapılmaz.
Cache süresi veri tipine göre belirlenir.
NETWORK
Timeout kullanılmalıdır.
Retry kontrollü yapılmalıdır.
Sonsuz tekrar yapılmaz.
Başarısız kaynak sistemi kilitlememelidir.
COLLECTOR KURALLARI
Collector'lar birbirinden bağımsız çalışmalıdır.
Bir collector hata verdi diye diğerleri durmamalıdır.
Collector kendi hatasını yönetebilmelidir.
COLLECTOR PERFORMANSI
Collector gereksiz çalıştırılmaz.
Değişmeyen veri tekrar indirilmez.
Hash veya tarih kontrolü kullanılmalıdır.
SCHEDULER
Bütün collector'lar aynı anda başlamaz.
Kademeli zamanlama uygulanır.
Sunucu yükü dengelenir.
AĞ KULLANIMI
Gereksiz HTTP isteği oluşturulmaz.
Tekrarlayan istekler önlenir.
Aynı veri tekrar tekrar çekilmez.
DOSYA OLUŞTURMA
Aynı amaç için ikinci dosya oluşturulmaz.
Mevcut yapı uygunsa genişletilir.
SİLME KURALI
Dosya silmeden önce;
aktif kullanım,
referans,
import,
bağımlılık
kontrol edilir.
Şüphe varsa silinmez.
YEDEKLEME
Riskli değişikliklerden önce geri dönüş planı oluşturulur.
Veri kaybı riski varsa işlem durdurulur.
TEST
Her önemli değişiklikten sonra;
Backend doğrulaması
Flutter doğrulaması
API doğrulaması
ayrı ayrı yapılır.
RAPOR
Her görev sonunda aşağıdaki başlıklar kullanılır:
• Yapılan işlemler
• Değişen dosyalar
• Test sonuçları
• Bulunan problemler
• Sonraki öneriler
TRENDORA ÖZEL GELİŞTİRME KURALLARI
Trendora yalnızca bir Flutter uygulaması değildir.
Backend, Collector, Analiz Motoru ve Flutter birlikte tek bir sistem olarak değerlendirilmelidir.
Yapılacak geliştirmeler sistemin tamamını düşünerek uygulanmalıdır.
ÇALIŞAN MODÜLLER
Çalışan hiçbir modül yeniden yazılmaz.
Örneğin;
Haber Merkezi
Fırsatlar Merkezi
Trend Tahmini
Dünya Taranıyor
Grafik Modülü
Premium
Profil
yalnızca üzerine geliştirilir.
YENİ ÖZELLİK
Yeni özellik eklenirken;
önce mevcut yapı incelenir.
Aynı işi yapan kod tekrar yazılmaz.
Var olan servis genişletilir.
KOD TEKRARI
Aynı işi yapan ikinci servis oluşturulmaz.
Aynı işi yapan ikinci model oluşturulmaz.
Aynı işi yapan ikinci API oluşturulmaz.
Tek sorumluluk korunmalıdır.
DOSYA SAYISI
Gereksiz dosya oluşturma.
Yeni dosya yalnızca gerçekten gerekiyorsa eklenir.
PERFORMANS
CPU kullanımını azalt.
RAM kullanımını azalt.
Disk kullanımını azalt.
Network kullanımını azalt.
Collector yükünü azalt.
Render sunucusunu gereksiz yorma.
HABER MERKEZİ
Mevcut haber sistemi korunacaktır.
Yeni kaynaklar mevcut sisteme entegre edilir.
RSS yapısı bozulmaz.
Duplicate haber oluşmasına izin verilmez.
FIRSATLAR MERKEZİ
Mevcut çalışan collector'lar korunacaktır.
Yeni mağaza eklenebilir.
Mevcut endpoint yapısı bozulmaz.
Aynı fırsat tekrar gösterilmez.
TREND ANALİZİ
Analiz motoru geliştirilebilir.
Ancak mevcut API korunacaktır.
Yeni alan gerekiyorsa eklenir.
Eski alanlar kaldırılmaz.
GRAFİK MODÜLÜ
Grafik performansı korunmalıdır.
Gerçek veriler kullanılmalıdır.
Demo veri yalnızca geliştirme amacıyla kullanılabilir.
CACHE
Her yeni özellikte cache ihtiyacı değerlendirilmelidir.
Gereksiz tekrar sorguları engellenmelidir.
COLLECTOR
Collector hata verse bile sistem çalışmaya devam etmelidir.
Bir collector diğer collector'ı durdurmamalıdır.
DÜŞÜK DONANIM MODU
Geliştirme yapılan bilgisayar:
Intel Core i3-7020U
4 GB RAM
HDD + 119 GB SSD
Bu nedenle;
aynı anda yalnızca tek ağır işlem çalıştır.
Paralel Flutter işlemi çalıştırma.
Paralel Gradle çalıştırma.
Paralel npm çalıştırma.
Paralel flutter analyze çalıştırma.
Paralel build başlatma.
Eski build bitmeden yenisini başlatma.
FLUTTER KOMUTLARI
flutter clean
yalnızca gerçekten gerekliyse.
flutter pub get
yalnızca package değiştiyse.
flutter analyze
önce değişen dosyalar için.
Tam analiz yalnızca gerektiğinde.
APK yalnızca kullanıcı isterse oluşturulur.
DEPLOY
Render Deploy kullanıcı istemedikçe yapılmaz.
APK kullanıcı istemedikçe oluşturulmaz.
Git Push kullanıcı istemedikçe yapılmaz.
KULLANICI ONAYI
Aşağıdaki işlemler için kullanıcı onayı gerekir.
Büyük Refactor
Dosya Taşıma
Klasör Taşıma
Database Migration
Yeni Package
SDK Güncellemesi
Android Manifest değişikliği
iOS yapılandırması
Build sistemi değişikliği
Deploy
Git Push
APK oluşturma
CODEX ÇALIŞMA KURALLARI
Her görevde:
Önce incele.
Sonra plan oluştur.
Sonra en küçük değişikliği uygula.
Sonra test et.
Sonra raporla.
Bir hata gördüğünde;
hemen büyük refactor yapma.
Önce gerçek sebebi araştır.
En küçük çözümü uygula.
Kullanıcı istemedikçe;
mimari değiştirme.
Dosya taşıma.
Kod temizliği adı altında çalışan kodu yeniden yazma.
AGENTS HİYERARŞİSİ
Birden fazla AGENTS.md bulunursa:
Proje kökündeki AGENTS.md okunur.

Daha sonra ilgili klasöre en yakın AGENTS.md uygulanır.

Çelişki varsa kullanıcıya sorulur.

SON KONTROL LİSTESİ
Her görev sonunda kendine şu soruları sor:
Çalışan sistemi bozdum mu?
Veri kaybı riski var mı?
API uyumluluğu korundu mu?
Gereksiz dosya oluşturdum mu?
Gereksiz refactor yaptım mı?
Performansı düşürdüm mü?
Test ettim mi?
Rapor hazırladım mı?
Bu sorulardan herhangi biri olumsuzsa görevi tamamlanmış kabul etme.
ALTIN KURAL
Her zaman aşağıdaki sırayı koru:
Çalışan sistemi bozma.

Veri güvenliğini koru.

En küçük değişikliği yap.

Geriye dönük uyumluluğu koru.

Test et.

Raporla.

Bozuk değilse dokunma.
ELECEK GELİŞTİRMELER
Yeni özellikler eklenirken mevcut mimari korunacaktır.
Kod yalnızca gerekli olduğu kadar değiştirilecektir.
Trendora zamanla büyüyecek şekilde geliştirilecektir.
Hiçbir geliştirme ileride yapılacak özellikleri zorlaştırmamalıdır.
SÜREKLİ İYİLEŞTİRME
Her görev sonunda aşağıdaki sorular değerlendirilmelidir:
Aynı işi daha az kaynak kullanarak yapabilir miyim?
Daha okunabilir bir çözüm var mı?
Kullanıcı deneyimi iyileşti mi?
Performans korundu mu?
Güvenlik korundu mu?
Bu değerlendirme yalnızca mevcut görev kapsamı içinde yapılır.
DOKÜMANTASYON
Yeni eklenen önemli modüller, servisler veya API'ler gerektiğinde kısa teknik açıklamalarla belgelenmelidir.
Dokümantasyon mevcut kodla uyumlu tutulmalıdır.
HATA YÖNETİMİ
Bir hata tespit edildiğinde:
Önce nedeni araştır.
Geçici çözüm yerine kalıcı çözüm uygula.
Gereksiz refactor yapma.
Çalışan kodu koru.
Test ederek doğrula.
KALİTE KONTROL
Görev tamamlanmadan önce aşağıdaki maddeler doğrulanmalıdır:
Kod derlenebilir durumda mı?
Yeni hata oluştu mu?
Eski özellikler çalışıyor mu?
Gereksiz dosya oluştu mu?
Performans olumsuz etkilendi mi?
Kullanıcı deneyimi korundu mu?
KALICI PRENSİPLER
Trendora geliştirilirken her zaman şu ilkeler uygulanacaktır:
Çalışan sistemi bozma.
Veri güvenliğini koru.
Geriye dönük uyumluluğu koru.
En küçük değişiklikle ilerle.
Gereksiz karmaşıklık oluşturma.
Performansı önceliklendir.
Güvenliği ihmal etme.
Test etmeden tamamlandı deme.
Kullanıcı istemedikçe build, deploy veya büyük mimari değişiklik yapma.
"Bozuk değilse dokunma." ilkesini koru.
AGENTS.md BAKIM KURALI
Bu dosya sık sık değiştirilmez.
Yalnızca uzun vadeli, genel geliştirme kuralları değiştiğinde güncellenir.
Geçici görevler veya tek seferlik istekler için AGENTS.md düzenlenmez.