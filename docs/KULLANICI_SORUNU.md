# Kullanıcı sorunu: talep değişikliklerinin izlenebilirliği

Bu belge, Capterra'da yayımlanmış bir kullanıcı yorumundan çıkardığımız
sorunu ve DestekAkış'ta bu soruna yönelik çözümü (ticket geçmişi / History)
anlatır.

## Kaynak

| | |
|---|---|
| Platform | Capterra, Zendesk Suite kullanıcı yorumları |
| Bağlantı | <https://www.capterra.com/p/164283/Zendesk/reviews/> |
| Yorum sahibi | Anita T. |
| Yorum başlığı | "Zendesk Suite: Powering support with confidence" |
| Yorum tarihi | 16 Aralık 2025 |
| Puan | 5.0 |
| Kısa alıntı | "Audit trail limited" |

Yorum **DestekAkış hakkında değildir**; başka bir destek yazılımının
kullanıcısı tarafından yazılmıştır. Biz yalnızca yorumda dile getirilen ihtiyacı
kendi küçük projemiz için ele alıyoruz. DestekAkış o ürünün arayüzünü, markasını
veya özelliklerini kopyalamaz.

Yorum sahibi, başlık, tarih, puan ve alıntı proje sahibi tarafından
tarayıcıda kaynak sayfada kontrol edilmiştir.

Yorumun genel puanı 5.0'dır; yani yorum sahibi ürünü genel olarak olumlu
değerlendirmektedir. "Audit trail limited" ifadesi bu olumlu değerlendirme
içindeki bir eksiklik notudur; ürünün tamamına yönelik bir şikâyet olarak
okunmamalıdır.

## Sorun tanımı

Alıntı kısa olduğu için yorumdan geniş sonuçlar çıkarmıyoruz. Dikkatli bir
okumayla çıkardığımız sorun şudur:

> Destek ekibindeki bir kullanıcı, bir talebin (ticket) zaman içinde nasıl
> değiştiğini — kimin, ne zaman, neyi değiştirdiğini — yeterince göremeyebilir.

Bu sorun tanımı:

- yalnızca **tek bir kullanıcının** görüşüne dayanır; tüm kullanıcıların böyle
  düşündüğü ya da sorunun ne kadar yaygın olduğu bu yorumdan anlaşılamaz;
- yorumun hangi kayıtların eksik olduğunu ayrıntılı anlatmadığını kabul eder;
- kurumsal uyumluluk, hukuki denetim veya güvenlik kaydı ihtiyacını
  kapsadığını iddia etmez.

## DestekAkış'taki çözüm: History

Her ticket'ın detay sayfasında bir **History** bölümü vardır. Bu bölüm, ticket
üzerinde kaydedilen olayları eskiden yeniye doğru, her satırda **zaman**,
**işlemi yapan** ve **açıklama** ile gösterir.

Kaydedilen olay türleri (`TicketEvent#kind`):

| Tür | Ne zaman oluşur | Örnek açıklama |
|---|---|---|
| `created` | Ticket oluşturulduğunda | `Ticket created` |
| `assigned` | Oluştururken atama yapıldığında; sonra atanan kişi değiştiğinde veya kaldırıldığında | `Assignee changed from Unassigned to Ayşe` |
| `status_changed` | Durum değiştiğinde (otomatik kapatma dahil) | `Status changed from solved to closed` |

Nasıl çalışır:

- Olaylar controller'da elle yazılmaz; `Ticket` modelinin `after_create` ve
  `after_update` callback'lerinde, ticket kaydıyla **aynı veritabanı
  transaction'ı içinde** oluşturulur. Ticket kaydedilip olay kaydedilemezse
  (ya da tersi) ikisi birlikte geri alınır.
- İşlemi yapan kişi `Current.user`'dır (oturum açmış kullanıcı). Arka plan
  işlerinde kullanıcı yoktur; bu durumda satırda **System** yazar. 72 saat
  kuralıyla yapılan otomatik kapatma bu şekilde görünür.
- Reddedilen bir değişiklik (ör. izin verilmeyen durum geçişi, geçersiz form)
  kaydedilmediği için geçmişte de görünmez.
- `kind` değeri hem model doğrulamasıyla hem SQLite CHECK kısıtıyla
  sınırlandırılmıştır; `ticket_id` ve `user_id` için foreign key vardır.

## İlgili dosyalar

**Model ve veritabanı**

- `app/models/ticket_event.rb` — geçmiş satırı, `kind` enum'u, `actor_name`
  ("System" gösterimi)
- `app/models/ticket.rb` — `has_many :events`, `record_creation_events`,
  `record_change_events`, `record_event`
- `app/models/user.rb` — `has_many :ticket_events, dependent: :nullify`
- `app/models/current.rb` — `Current.user`
- `db/migrate/20261016112438_create_ticket_events.rb`, `db/schema.rb` —
  `ticket_events` tablosu, CHECK kısıtı, foreign key'ler
- `app/jobs/auto_close_solved_tickets_job.rb` — otomatik kapatma; geçmişte
  System olarak görünür

**Controller ve görünüm**

- `app/controllers/tickets_controller.rb` — `show` eylemi `@events`'i yükler
- `app/views/tickets/show.html.erb` — **History** bölümü
- `app/assets/stylesheets/application.css` — geçmiş listesinin stili

**Testler**

- `test/models/ticket_event_test.rb` — oluşturma, atama, durum değişikliği
  olayları; reddedilen değişikliğin kaydedilmemesi; sıralama; System kullanıcısı;
  geçersiz `kind`; kullanıcı silindiğinde olayların korunması
- `test/controllers/tickets_controller_test.rb` — oluşturma ve düzenlemede
  işlemi yapanın kaydedilmesi, başarısız güncellemenin olay üretmemesi,
  History bölümünün sırası, kullanıcı ve zamanla gösterilmesi
- `test/controllers/ticket_statuses_controller_test.rb` — durum değişikliğini
  kimin yaptığının kaydedilmesi, reddedilen değişikliğin geçmişe girmemesi
- `test/jobs/auto_close_solved_tickets_job_test.rb` — otomatik kapatmanın
  geçmişte System olarak görünmesi

## Çözümün sınırları

History, küçük bir ekip için **talep düzeyinde bir değişiklik geçmişidir**;
eksiksiz bir kurumsal denetim (audit) sistemi değildir. Yalnızca kaydedilen
olaylar görünür:

- **Yalnızca üç olay türü kaydedilir:** oluşturma, atama ve durum değişikliği.
  Konu, açıklama, öncelik ve talep eden bilgisindeki değişiklikler geçmişe
  yazılmaz; bu alanların eski değerleri saklanmaz.
- **Ticket dışındaki işlemler kaydedilmez:** giriş/çıkış, başarısız giriş
  denemeleri, parola sıfırlama, kullanıcı oluşturma ve sayfa görüntülemeleri
  geçmişte yer almaz.
- **Kullanıcı silinirse** o kullanıcının olayları korunur ama işlemi yapan
  bilgisi kaybolur ve satır "System" olarak görünür.
- **Doğrulamayı atlayan kod** (`update_column`, `update_all`, doğrudan SQL)
  callback'leri çalıştırmadığı için olay üretmez.
- **Değiştirilemezlik garanti edilmez:** veritabanına erişimi olan biri olayları
  değiştirebilir veya silebilir; imza, hash zinciri gibi bir koruma yoktur.
  Bir ticket silinirse olayları da silinir (`dependent: :destroy`); arayüzde
  ticket silme olmasa da model buna izin verir.
- **Arama, filtreleme, dışa aktarma ve saklama süresi politikası yoktur;**
  geçmiş yalnızca ticket detay sayfasında okunabilir.
- **IP adresi, tarayıcı bilgisi gibi bağlam bilgileri tutulmaz.**
- Render ücretsiz planında veritabanının kalıcılığı garanti edilmediği için
  deploy, yeniden başlatma veya uyku modunda geçmiş de silinebilir (bkz.
  `docs/DEPLOY_RENDER.md`).

Bu sınırlar, DestekAkış'ın ödev kapsamında sade tutulması için bilinçli olarak
kabul edilmiştir.
