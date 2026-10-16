# DestekAkış

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
  her kayıtta işlemi yapan kullanıcı ve zaman bilgisi bulunur. Otomatik
  kapatma "System" olarak görünür.

## Teknoloji yığını

| Katman | Kullanılan |
|---|---|
| Dil / çatı | Ruby 3.4.11, Rails 8.1.4 |
| Veritabanı | SQLite (`sqlite3` gem 2.x) |
| Arayüz | Sunucu tarafı ERB görünümleri, Propshaft, importmap, düz CSS |
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

## Testler ve kontroller

```bash
bin/rails test        # tüm testler (model, controller, entegrasyon, job)
bin/rubocop           # stil kontrolü
bin/brakeman          # güvenlik taraması
bin/bundler-audit     # gem güvenlik açıkları
```

GitHub Actions (`.github/workflows/ci.yml`) her push ve pull request'te
testleri, RuboCop'u ve güvenlik taramalarını çalıştırır. Ruby sürümü
`.ruby-version` dosyasından okunur
([ruby/setup-ruby](https://github.com/ruby/setup-ruby)).

## İş kuralları

### Durum geçişleri

```
open    -> pending, solved
pending -> open, solved
solved  -> open, closed
closed  -> (hiçbiri)
```

Kurallar `Ticket::TRANSITIONS` içinde tanımlıdır ve model doğrulaması olarak
uygulanır. Yeni ticket her zaman `open` başlar. Durum yalnızca ticket detay
sayfasındaki butonlarla değiştirilir; düzenleme formu `status` alanını kabul
etmez.

### 72 saat sonra otomatik kapatma

1. `AutoCloseSolvedTicketsJob`, `updated_at` değeri en az 72 saat önce olan
   `solved` ticket'ları bulur (`Ticket.ready_to_auto_close`).
2. Her birini kilitleyip yeniden okur; arada değiştiyse dokunmaz.
3. `transition_to("closed")` ile kapatır, yani normal geçiş kuralları geçerlidir.

Ölçü `updated_at` olduğu için `solved` bir ticket'ta yapılan **her değişiklik**
(yeniden açma, düzenleme, atama) 72 saatlik süreyi baştan başlatır. Sınır
dahildir: tam 72. saatte kapanır, 71 saat 59 dakikada kapanmaz. Bu senaryolar
[`travel_to`](https://api.rubyonrails.org/classes/ActiveSupport/Testing/TimeHelpers.html)
ile `test/jobs/auto_close_solved_tickets_job_test.rb` içinde test edilir.

Production'da görev `config/recurring.yml` ile saatte bir çalışır. Bunun için
Solid Queue'nun Puma içinde başlatılması gerekir (`SOLID_QUEUE_IN_PUMA=true`,
bkz. [Solid Queue](https://github.com/rails/solid_queue)).

## Render dağıtımı

Ayrıntılar: [`docs/DEPLOY_RENDER.md`](docs/DEPLOY_RENDER.md).

Kısaca: `render.yaml` Dockerfile ile bir web servisi tanımlar, otomatik deploy
kapalıdır, sağlık kontrolü `/up`'tır. Gereken ortam değişkenleri
`SECRET_KEY_BASE` (Render üretir), `SOLID_QUEUE_IN_PUMA=true`,
`PORT`/`HTTP_PORT=10000` ve ilk admin için `ADMIN_NAME`, `ADMIN_EMAIL`,
`ADMIN_PASSWORD`'dür. Uygulama henüz deploy edilmemiştir.

## Bilinen sınırlamalar

- **Render ücretsiz planında veri kalıcı değildir.** Ücretsiz web servislerinin
  dosya sistemi geçicidir ve kalıcı disk eklenemez; SQLite dosyaları her
  deploy, yeniden başlatma ve uyku modunda silinir
  ([Render: Deploy for Free](https://render.com/docs/free)). Kalıcılık için
  ücretli bir instance'a disk bağlamak ya da barındırılan bir veritabanı
  kullanmak gerekir.
- **Ücretsiz servis uyur.** Trafik yoksa servis durur; bu sırada zamanlanmış
  görev çalışmaz. Süresi dolan ticket'lar servis uyandıktan sonraki ilk
  saatlik çalışmada kapanır.
- **Ücretsiz planda shell yoktur** ([Render: SSH and Shell Access](https://render.com/docs/ssh));
  bu yüzden Render'da ilk admin `db/seeds.rb` ile oluşturulur.
- **Parola sıfırlama e-postaları gönderilmez;** e-posta servisi ayarlı değildir.
- **Arayüz metinleri İngilizcedir.**
- Durum geçiş kuralları veritabanı seviyesinde değil, model seviyesinde
  uygulanır (`update_column` gibi doğrulamayı atlayan kod bunları aşabilir).

## Yapamadıklarım

Bu bölüm, projenin şu anki durumunda yapılmamış ya da doğrulanamamış işleri
listeler:

- **Uygulama deploy edilmedi.** Render hesabı oluşturulmadı; ücretli hizmet
  kullanılmadı.
- **Docker imajı yerelde derlenmedi** (geliştirme makinesinde Docker kurulu
  değil). Container'ın başlangıç komutu Docker olmadan, production ortamında
  yerelde çalıştırılarak denendi: veritabanları oluştu, admin seed edildi,
  `/up` 200 döndü, Solid Queue'nun scheduler'ı ve worker'ı çalıştı.
- **GitHub Actions workflow'u henüz GitHub'da çalışmadı;** depo GitHub'a
  gönderilmedi. Workflow'daki komutlar yerelde başarıyla çalıştı, ancak
  `ruby/setup-ruby`'nin Ruby 3.4.11'i sağladığı ilk çalıştırmada görülecek.
- **Tarayıcı (system) testleri yok;** arayüz entegrasyon testleriyle
  (HTML çıktısı üzerinden) test edildi.
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
config/recurring.yml                       saatlik zamanlama (production)
render.yaml, docs/DEPLOY_RENDER.md         Render yapılandırması
AGENT.md                                   geliştirici/ajan kuralları
```
