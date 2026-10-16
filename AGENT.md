# AGENT.md

Bu dosya, DestekAkış üzerinde çalışan geliştiriciler ve kodlama ajanları içindir.
Kullanıcıya yönelik genel bilgi için [README.md](README.md) dosyasına bakın.

## Mimari

Klasik, sunucu tarafında render edilen bir Rails 8.1 uygulaması; tek bir SQLite
veritabanı (production'da ek olarak cache, queue ve cable veritabanları).

```
Tarayıcı ──> Controller'lar ──> Modeller ──> SQLite
                                   │
                    Solid Queue ───┘  (AutoCloseSolvedTicketsJob, saatte bir)
```

| Parça | Sorumluluk |
|---|---|
| `Authentication` concern (`app/controllers/concerns/authentication.rb`) | Rails 8 oluşturucusundan gelir. Her controller varsayılan olarak giriş ister; `Current.user` oturum açmış kullanıcıdır. |
| `User` | `agent` / `admin` rolleri, bcrypt parola (en az 8 karakter). |
| `UsersController` | Yalnızca admin: kullanıcı listeleme ve oluşturma. Herkese açık kayıt yok. |
| `Ticket` | Alan doğrulamaları, `TRANSITIONS` tablosu, `transition_to`, `ready_to_auto_close` scope'u, geçmiş callback'leri. |
| `TicketEvent` | Geçmiş satırı: `ticket`, `user` (boş = System), `kind`, `description`, `created_at`. |
| `TicketsController` | index/new/create/show/edit/update. `status` parametresine izin vermez. |
| `TicketStatusesController` | `PATCH /tickets/:id/status`; yalnızca `transition_to` çağırır. |
| `AutoCloseSolvedTicketsJob` | 72 saat kuralı; `config/recurring.yml` ile zamanlanır. |

## İş kuralları (değiştirmeden önce sorun)

1. **Durum geçişleri** yalnızca `Ticket::TRANSITIONS` ile tanımlanır:
   `open → pending/solved`, `pending → open/solved`, `solved → open/closed`,
   `closed →` hiçbiri. Yeni ticket her zaman `open` başlar.
   Durumu değiştirmek için `transition_to` (veya doğrulama çalıştıran
   `update`) kullanın; `update_column` / `update_all` ile durum değiştirmeyin.
2. **72 saat kuralı:** `solved` ve `updated_at <= şimdi - 72 saat` olan ticket
   kapanır (`Ticket::AUTO_CLOSE_AFTER`). Sınır dahildir. Her değişiklik süreyi
   yeniden başlatır. Job, her ticket'ı kilit altında yeniden kontrol eder.
3. **Geçmiş kaydı** `Ticket` callback'lerinde, ticket kaydıyla aynı transaction
   içinde oluşturulur: oluşturma, atama değişikliği, durum değişikliği.
   İşlemi yapan `Current.user`'dır; job'larda boştur ve "System" gösterilir.
   Yeni bir değişiklik akışı eklerken geçmişi controller'da elle yazmayın.
4. **Yetki:** oturum açmamış kullanıcı hiçbir ticket sayfasına erişemez.
   Kullanıcı yönetimi yalnızca admin içindir. Herkese açık kayıt eklemeyin.
5. **Veri bütünlüğü:** `role`, `priority`, `status` ve `kind` için hem model
   doğrulaması hem SQLite CHECK kısıtı vardır; `assigned_to_id` ve
   `ticket_events` için foreign key'ler vardır. Yeni bir değer eklerken ikisini
   birlikte güncelleyin (migration + enum).

## Komutlar

```bash
bin/rails test                                    # tüm testler
bin/rails test test/models/ticket_test.rb         # tek dosya
bin/rubocop                                       # stil
bin/brakeman                                      # güvenlik
bin/rails db:migrate                              # migration
bin/rails users:create_admin NAME=... EMAIL=... PASSWORD=...
bin/rails runner "AutoCloseSolvedTicketsJob.perform_now"
```

## Test kuralları

- Minitest ve `test/fixtures/*.yml` kullanılır; yeni gem eklemeden önce sorun.
- Zamana bağlı her davranış `travel_to` / `travel` ile, sabit zamanlarla test
  edilir. Fixture'ların zaman damgaları yükleme anına bağlıdır; kesin zaman
  gereken testlerde kendi kayıtlarınızı oluşturun.
- Reddedilen bir değişiklikte hem dönüş değerini hem veritabanındaki değeri
  kontrol edin (`test/models/ticket_test.rb` içindeki `assert_rejected`).
- Entegrasyon testlerinde `sign_in_as(users(:agent))` yardımcısını kullanın.
- Bir değişiklikten sonra ilgili testleri, ardından tüm paketi, RuboCop'u ve
  Brakeman'ı çalıştırın. Sonuçları uydurmayın; başarısızlığı olduğu gibi
  bildirin.

## Geliştirme kuralları

- **Marka:** uygulamanın adı DestekAkış'tır. Arayüze başka bir SaaS markasının
  adını veya logosunu eklemeyin.
- **Sadelik:** kod bir yazılım mühendisliği öğrencisinin anlayabileceği kadar
  basit kalmalı. Sunucu tarafı ERB görünümleri ve düz CSS kullanılır; JS build
  adımı yoktur.
- **Kapsam:** istenmeyen özellik eklemeyin. Kapsam dışı fikirleri önerin, ama
  uygulamayın.
- **Bağımlılık:** yeni gem veya paket eklemeden önce onay alın.
- **Git:** Git kimliğini veya global Git ayarlarını değiştirmeyin. Onay
  almadan commit oluşturmayın, push yapmayın.
- **Dağıtım ve maliyet:** onay almadan deploy etmeyin, harici hesap
  oluşturmayın, ücretli hizmet seçmeyin.
- **Gizli bilgiler:** `config/master.key`, veritabanı dosyaları ve parolalar
  depoya girmez (`.gitignore` bunları dışarıda tutar).
