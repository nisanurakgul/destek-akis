# DestekAkış

[![CI](https://github.com/nisanurakgul/destek-akis/actions/workflows/ci.yml/badge.svg)](https://github.com/nisanurakgul/destek-akis/actions/workflows/ci.yml)

**Canlı demo:** <https://destek-akis.onrender.com> (`render.yaml`'a göre
Render ücretsiz planı; ilk istek servis uyanırken yaklaşık bir dakika
sürebilir ve verilerin kalıcılığı garanti edilmez, bkz.
[Bilinen sınırlamalar](#bilinen-sınırlamalar)).

Kullanıcı yorumu, sorun tanımı ve çözüm:
[`docs/KULLANICI_SORUNU.md`](docs/KULLANICI_SORUNU.md).

DestekAkış, bir yazılım mühendisliği dersi ödevi için geliştirilmiş, sunucu
tarafında render edilen basit bir **müşteri destek talebi (ticket) sistemidir**.
Destek ekibi talepleri oluşturur, kişilere atar, durumlarını kurallara uygun
şekilde değiştirir ve her talebin geçmişini görür. Çözülmüş ama 72 saat boyunca
değişmeyen talepler otomatik olarak kapatılır.

Kod, bir öğrencinin okuyup anlayabileceği şekilde sade tutulmuştur.

## Özellikler

- **Kimlik doğrulama:** Rails 8'in yerleşik authentication oluşturucusu
  (bcrypt ile `has_secure_password`, veritabanında tutulan oturumlar, parola
  sıfırlama akışı). Herkese açık kayıt sayfası yoktur.
- **Roller:** `agent` (varsayılan) ve `admin`. Yalnızca admin yeni kullanıcı
  oluşturabilir (`/users`).
- **Ticket yönetimi:** listeleme, oluşturma, detay, düzenleme. Konu, açıklama,
  talep eden adı/e-postası, öncelik (`low`, `normal`, `high`, `urgent`), durum
  ve isteğe bağlı atanan kullanıcı.
- **Durum geçiş kuralları:** `open`, `pending`, `solved`, `closed`. Yalnızca
  izin verilen geçişler yapılabilir; `closed` son durumdur.
- **72 saat kuralı:** `solved` durumunda 72 saat değişmeyen ticket otomatik
  olarak `closed` olur.
- **Geçmiş (TicketEvent):** oluşturma, atama değişikliği ve durum değişikliği;
  her kayıtta işlemi yapan kullanıcı ve zaman bilgisi bulunur. Talep detay
  sayfasında "İşlem geçmişi" başlığıyla gösterilir; otomatik kapatma
  "Sistem" olarak görünür.
- **Arayüz:** Türkçe, sol menülü bir yönetim paneli. Sayfalar: giriş ve
  parola sıfırlama, genel bakış (duruma göre talep sayıları, kullanıcıya
  atanmış açık/bekleyen talep sayısı), talep listesi, talep oluşturma,
  detay ve düzenleme, kullanıcı listesi ve kullanıcı oluşturma (yalnızca
  admin). Durum ve öncelikler renkli etiketlerle gösterilir (durumlar:
  Açık, Beklemede, Çözüldü, Kapalı; öncelikler: Düşük, Normal, Yüksek,
  Acil); veritabanında İngilizce değerler (`open`, `high` vb.) saklanmaya
  devam eder. Arayüz masaüstü öncelikli olup dar ekranlarda da kullanılabilir
  (mobilde talep listesi kart görünümüne geçer). 400, 404, 422, 500 ve
  desteklenmeyen tarayıcı hata sayfaları da Türkçedir.

## Kullanıcı sorunu

Geçmiş özelliği (arayüzde "İşlem geçmişi"), başka bir destek yazılımı hakkında Capterra'da
yayımlanmış bir kullanıcı yorumunda belirtilen sınırlı denetim izi
eksikliğiyle ilişkilendirilmiştir: Anita T., "Zendesk Suite: Powering support
with confidence", 16 Aralık 2025, puan 5.0, alıntı: "Audit trail limited"
([Capterra](https://www.capterra.com/p/164283/Zendesk/reviews/)). Kaynak
tarayıcıda kontrol edilmiştir. Yorumun kaynağı, sorun tanımı, çözümün ilgili
dosyaları ve testleri ile çözümün sınırları
[`docs/KULLANICI_SORUNU.md`](docs/KULLANICI_SORUNU.md) belgesindedir. Yorum
DestekAkış hakkında yazılmamıştır; geçmiş özelliği de eksiksiz bir kurumsal denetim
sistemi değildir, yalnızca kaydedilen olayları gösterir.

## Teknoloji yığını

| Katman | Kullanılan |
|---|---|
| Dil / çatı | Ruby 3.4.11, Rails 8.1.4 |
| Veritabanı | SQLite (`sqlite3` gem 2.x) |
| Arayüz | Sunucu tarafı ERB görünümleri, Propshaft, importmap, Turbo; tek dosyada düz CSS (`app/assets/stylesheets/application.css`) ve satır içi SVG ikonlar. Ek CSS/JS kütüphanesi ve build adımı yoktur. |
| Arka plan işleri | Solid Queue (zamanlanmış görevler `config/recurring.yml`) |
| Testler | Minitest, fixture'lar, `travel_to` |
| Kalite | RuboCop (rails-omakase), Brakeman, bundler-audit |
| Dağıtım | Dockerfile + Thruster, Render Blueprint (`render.yaml`) |

## Yerel kurulum ve çalıştırma

Gereken: Ruby 3.4.11 (sürüm `.ruby-version` dosyasındadır; bu projede
[mise](https://mise.jdx.dev/) ile kurulmuştur). SQLite için ayrıca sistem
paketi gerekmez; `sqlite3` gem'i SQLite kütüphanesini kendi içinde getirir
([sqlite3-ruby](https://github.com/sparklemotion/sqlite3-ruby)).

```bash
bin/setup --skip-server   # gem'leri kurar, veritabanlarını hazırlar
bin/rails server          # http://localhost:3000
```

Tarayıcıda <http://localhost:3000> açıldığında, oturum yoksa giriş sayfasına
yönlendirilirsiniz.

### İlk admin kullanıcısını oluşturma

Kayıt sayfası olmadığı için ilk admin komut satırından oluşturulur:

```bash
bin/rails users:create_admin NAME="Ad Soyad" EMAIL=admin@example.com PASSWORD=en-az-8-karakter
```

Ardından admin olarak giriş yapıp `/users` sayfasından agent oluşturabilirsiniz.

Alternatif olarak (Render'da kullanılan yol) `ADMIN_NAME`, `ADMIN_EMAIL` ve
`ADMIN_PASSWORD` ortam değişkenleriyle `bin/rails db:seed` çalıştırılabilir.

### 72 saat kuralını elle çalıştırma

Geliştirme ortamında zamanlanmış görevler otomatik çalışmaz. Kuralı elle
denemek için:

```bash
bin/rails runner "AutoCloseSolvedTicketsJob.perform_now"
```

### Örnek (demo) talepler

Liste, durumlar ve geçmiş boş görünmesin diye 18 örnek talep eklenebilir:

```bash
bin/rails demo:seed
```

Görev (`lib/tasks/demo.rake`) yalnızca ekleme yapar: aynı konu ve e-postaya
sahip bir talep zaten varsa onu atlar; mevcut kullanıcıları, talepleri ve
geçmişi değiştirmez veya silmez, yeni kullanıcı oluşturmaz. Talepleri var olan
kullanıcılara atar ve geçmişi normal model callback'leriyle, geçmiş tarihlerle
yazar. En az bir kullanıcı gerekir. Production'da yalnızca
`DEMO_SEED_IN_PRODUCTION=1` ile çalışır. Render'da açılışta otomatik
çalıştırma için bkz. [Render dağıtımı](#render-dağıtımı).

## Testler ve kontroller

```bash
bin/rails test        # tüm testler (model, controller, entegrasyon, job)
bin/rubocop           # stil kontrolü
bin/brakeman          # güvenlik taraması
bin/bundler-audit     # gem güvenlik açıkları
```

GitHub Actions (`.github/workflows/ci.yml`) `main`'e her push'ta ve her pull
request'te testleri, RuboCop'u ve güvenlik taramalarını çalıştırır. Ruby sürümü
`.ruby-version` dosyasından okunur
([ruby/setup-ruby](https://github.com/ruby/setup-ruby)). Güncel durum yukarıdaki
CI rozetinde görünür.

Son yerel çalıştırma (16 Ekim 2026, demo verisi ve açılışta demo seçeneği
eklendikten sonra): `bin/rails test` 172 test ve 933 doğrulama için 0
başarısızlık, 0 hata ve 0 atlama bildirdi; `bin/rubocop` uyarı bulmadı;
`bin/brakeman` 0 güvenlik uyarısı bildirdi. Bu sonuçlar henüz CI'da
doğrulanmadı.

Son CI kaydı: 16 Ekim 2026'da `main` üzerinde arayüz yenilemesi commit'i
`4ad9849` için yapılan çalıştırmada dört iş de (`test`, `lint`, `scan_ruby`,
`scan_js`) geçti; test işi o sürümdeki 158 test ve 803 doğrulama için 0
başarısızlık ve 0 hata bildirdi
([çalıştırma](https://github.com/nisanurakgul/destek-akis/actions/runs/38957524979)).

## İş kuralları

### Durum geçişleri

```
open    -> pending, solved
pending -> open, solved
solved  -> open, closed
closed  -> (hiçbiri)
```

Kurallar `Ticket::TRANSITIONS` içinde tanımlıdır ve model doğrulaması olarak
uygulanır. Yeni ticket her zaman `open` (arayüzde "Açık") başlar. Durum
yalnızca ticket detay sayfasındaki "Durumu değiştir" butonlarıyla
değiştirilir (`PATCH /tickets/:id/status`); sayfada yalnızca mevcut durumdan
izin verilen geçişlerin butonları gösterilir ("Beklemeye al", "Çözüldü olarak
işaretle", "Yeniden aç", "Kapat"). Düzenleme formu `status` alanını kabul
etmez.

### 72 saat sonra otomatik kapatma

1. `AutoCloseSolvedTicketsJob`, `updated_at` değeri en az 72 saat önce olan
   `solved` ticket'ları bulur (`Ticket.ready_to_auto_close`).
2. Her birini kilitleyip yeniden okur; arada değiştiyse dokunmaz.
3. `transition_to("closed")` ile kapatır, yani normal geçiş kuralları geçerlidir.
   Geçmişe işlemi yapan olarak "Sistem" yazılır.

Ölçü `updated_at` olduğu için `solved` bir ticket'ta yapılan **her değişiklik**
(yeniden açma, düzenleme, atama) 72 saatlik süreyi baştan başlatır. Sınır
dahildir: tam 72. saatte kapanır, 71 saat 59 dakikada kapanmaz. Bu senaryolar
[`travel_to`](https://api.rubyonrails.org/classes/ActiveSupport/Testing/TimeHelpers.html)
ile `test/jobs/auto_close_solved_tickets_job_test.rb` içinde test edilir.

Çözülmüş bir ticket'ın detay sayfası, değişiklik yapılmazsa hangi tarihten
sonra otomatik kapatılacağını gösterir (`updated_at + 72 saat`). Görev saatte
bir çalıştığı için kapanma bu andan sonraki ilk çalıştırmada gerçekleşir.

Production'da görev `config/recurring.yml` ile saatte bir çalışır. Bunun için
Solid Queue'nun Puma içinde başlatılması gerekir (`SOLID_QUEUE_IN_PUMA=true`,
bkz. [Solid Queue](https://github.com/rails/solid_queue)).

## Render dağıtımı

Ayrıntılar: [`docs/DEPLOY_RENDER.md`](docs/DEPLOY_RENDER.md).

Kısaca: `render.yaml` Dockerfile ile bir web servisi tanımlar, otomatik deploy
kapalıdır, sağlık kontrolü `/up`'tır. Gereken ortam değişkenleri
`SECRET_KEY_BASE` (Render üretir), `SOLID_QUEUE_IN_PUMA=true`,
`PORT`/`HTTP_PORT=10000` ve ilk admin için `ADMIN_NAME`, `ADMIN_EMAIL`,
`ADMIN_PASSWORD`'dür.

Uygulama <https://destek-akis.onrender.com> adresinde yayındadır. Plan
`render.yaml`'da `plan: free` olarak tanımlıdır; Render panelindeki plan bu
belge için ayrıca kontrol edilmedi. 16 Ekim 2026'da yapılan kontrolde ilk istek
servis uyanırken 502 döndü, ardından `/up` 200 döndü ve ana sayfa giriş
sayfasına yönlendirdi. **Bu ortamda SQLite verilerinin kalıcılığı garanti
değildir:** ticket'lar, kullanıcılar ve geçmiş her deploy, yeniden başlatma ve
uyku modunda silinebilir; servis yeniden başladığında yalnızca ortam
değişkenlerindeki admin yeniden oluşturulur.

### Canlı demoda örnek talepler (isteğe bağlı)

Ücretsiz planda veritabanı her açılışta boş başladığı için örnek talepler de
her uyanışta silinir. Bunları her açılışta yeniden eklemek için Render
panelinde servise `DEMO_SEED_ON_BOOT=1` ortam değişkeni eklenip deploy
yapılır. Bu değişken `render.yaml`'da tanımlı değildir ve varsayılan olarak
kapalıdır.

- `bin/docker-entrypoint`, `db:prepare`'den (ve ilk admin seed'inden) sonra
  `DEMO_SEED_IN_PRODUCTION=1 bin/rails demo:seed` çalıştırır, ardından
  sunucuyu başlatır.
- Yalnızca tam olarak `1` değeri etkinleştirir; değişken yoksa veya başka bir
  değerdeyse açılış eskisi gibidir.
- Seed başarısız olursa (ör. hiç kullanıcı yoksa) hata günlüğe yazılır ve
  sunucu örnek veri olmadan başlar. `db:prepare` başarısız olursa açılış eskisi
  gibi durur.
- Görev yalnızca eksik örnek talepleri ekler; veri silmez veya değiştirmez.
  Örnek geçmiş, var olan kullanıcıların (ücretsiz planda yalnızca ortam
  değişkenlerindeki admin) adına yazılır.
- Kapatmak için değişkeni silip yeniden deploy etmek yeterlidir.

Bu davranış `test/bin/docker_entrypoint_test.rb` ile test edilir ve yerelde,
production modunda gerçek açılış komutuyla denendi (bkz.
[Yapamadıklarım](#yapamadıklarım)).

## Bilinen sınırlamalar

- **Render ücretsiz planında veri kalıcı değildir.** Ücretsiz web servislerinin
  dosya sistemi geçicidir ve kalıcı disk eklenemez; SQLite dosyaları her
  deploy, yeniden başlatma ve uyku modunda silinir
  ([Render: Deploy for Free](https://render.com/docs/free)). Kalıcılık için
  ücretli bir instance'a disk bağlamak ya da barındırılan bir veritabanı
  kullanmak gerekir.
- **Ücretsiz servis uyur.** Trafik yoksa servis durur; bu sırada zamanlanmış
  görev çalışmaz. Job süresi geçmiş tüm ticket'ları kapattığı için (geç
  çalışma testlerde doğrulanmıştır) bu ticket'ların servis uyandıktan sonraki
  ilk saatlik çalışmada kapanması beklenir; bu canlı ortamda gözlemlenmedi.
- **Ücretsiz planda shell yoktur** ([Render: SSH and Shell Access](https://render.com/docs/ssh));
  bu yüzden Render'da ilk admin `db/seeds.rb` ile oluşturulur.
- **Parola sıfırlama e-postaları gönderilmez;** e-posta servisi ayarlı değildir.
- **Arayüz Türkçedir, ancak bazı metinler İngilizce kalmıştır:** model
  doğrulama hata mesajları (ör. "Subject can't be blank") ve veritabanına
  yazılan geçmiş açıklamaları (ör. "Status changed from open to solved").
  Eski kayıtları değiştirmemek için bunlar çevrilmedi.
- **Saatler UTC olarak gösterilir;** `config.time_zone` ayarlanmamıştır.
- Durum geçiş kuralları veritabanı seviyesinde değil, model seviyesinde
  uygulanır (`update_column` gibi doğrulamayı atlayan kod bunları aşabilir).

## Yapamadıklarım

Bu bölüm, projenin şu anki durumunda yapılmamış ya da doğrulanamamış işleri
listeler:

- **Kalıcı veri yok.** Canlı demo ücretsiz planda çalışır; kalıcı disk veya
  barındırılan veritabanı kullanılmadı (ücretli hizmet seçilmedi). Demo
  verileri her an silinebilir.
- **Canlı ortamda 72 saat kuralı ve Solid Queue doğrulanmadı.** Render'da
  yalnızca `/up` ve giriş sayfasına yönlendirme kontrol edildi; servis uyuduğu
  için zamanlanmış görevin orada çalıştığı gözlemlenmedi.
- **Docker imajı yerelde derlenmedi** (geliştirme makinesinde Docker kurulu
  değil). Render'daki servis `render.yaml`'a göre (`runtime: docker`)
  Dockerfile'dan derlenir; Render derleme günlüğü bu belge için incelenmedi.
  Container'ın başlangıç komutu ayrıca Docker olmadan, production ortamında
  yerelde çalıştırılarak denendi: veritabanları oluştu, admin seed edildi,
  `/up` 200 döndü, Solid Queue'nun scheduler'ı ve worker'ı çalıştı.
  `DEMO_SEED_ON_BOOT` da aynı şekilde (Docker olmadan) denendi: değişken
  yokken 0 talep, `1` iken boş veritabanında 18 talep oluştu, aynı veritabanıyla
  yeniden açılışta hiçbir şey eklenmedi ve `/up` her seferinde 200 döndü.
  Render'da henüz denenmedi.
- **Dependabot'un açtığı iki pull request'te** (`actions/checkout` 7 ve
  `actions/cache` 6 güncellemeleri) CI başarısız oldu; başarısızlığın nedeni
  incelenmedi, iki pull request de açık ve birleştirilmemiş durumda.
- **Tarayıcı (system) testleri yok;** arayüz entegrasyon testleriyle
  (HTML çıktısı üzerinden) test edildi. Yenilenen arayüz ayrıca masaüstü
  (1440 px) ve mobil (390 px) genişlikte headless Chrome ile bir kez elle
  kontrol edildi; bu kontrol otomatik değildir ve başka tarayıcılarda
  denenmedi.
- **Giriş deneme sınırı (rate limit) test edilmedi;** test ortamında önbellek
  kapalı olduğu için devreye girmez.
- **Kullanıcı düzenleme/silme, ticket silme, arama ve filtreleme yok;**
  ödev kapsamı dışında bırakıldı.
- **Aynı anda düzenlemeye karşı kilit yok** (yalnızca otomatik kapatma işi
  kilit kullanır).

## Proje yapısı (önemli dosyalar)

```
app/models/ticket.rb                       durum kuralları, 72 saat scope'u, geçmiş callback'leri
app/models/ticket_event.rb                 geçmiş kaydı
app/models/user.rb                         roller, parola kuralları
app/controllers/tickets_controller.rb      liste, oluşturma, detay, düzenleme
app/controllers/ticket_statuses_controller.rb  durum değiştirme
app/controllers/users_controller.rb        admin'e özel kullanıcı yönetimi
app/jobs/auto_close_solved_tickets_job.rb  72 saat kuralı
lib/tasks/demo.rake                        18 örnek talep (bin/rails demo:seed)
bin/docker-entrypoint                      container açılışı: db:prepare, isteğe bağlı demo seed
app/views/layouts/application.html.erb     sol menülü uygulama düzeni ve giriş sayfası düzeni
app/helpers/tickets_helper.rb              durum/öncelik etiketlerinin Türkçe karşılıkları
app/assets/stylesheets/application.css     tüm arayüz stilleri (düz CSS)
config/recurring.yml                       saatlik zamanlama (production)
render.yaml, docs/DEPLOY_RENDER.md         Render yapılandırması
docs/KULLANICI_SORUNU.md                   kullanıcı yorumu, sorun tanımı ve İşlem geçmişi çözümü
AGENT.md                                   geliştirici/ajan kuralları
```
