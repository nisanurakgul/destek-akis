# Adds example tickets for a live demo, so the ticket list, priorities, statuses
# and history are not empty.
#
#   bin/rails demo:seed
#
# Safe to run more than once: a demo ticket is skipped when a ticket with the
# same subject and requester email already exists. Existing records are never
# changed or deleted.
#
# How the data is made:
#   - Tickets are created and changed through the normal model methods
#     (create!, update!, transition_to), so the status rules apply and the
#     history (TicketEvent) is written by the Ticket callbacks as usual.
#   - Each step runs at a moment in the past (travel_to), so the history shows
#     realistic times. Nothing is dated in the future.
#   - Steps are done "as" an existing user by setting Current.session to an
#     unsaved Session for that user; no session is stored. Steps marked
#     :system run without a user and show as "System", like the 72 hour job.
#   - Only existing users are used. Agents get the assignments; with a single
#     user, everything is assigned to that user.
#
# 72 hour rule: every solved demo ticket was last changed less than 72 hours
# before the seed runs, so it is still solved right after seeding. It will be
# auto-closed 72 hours after its last change (see SOLVED_HOURS_AGO below), so
# run the seed on the day of the demo. Closed demo tickets were closed either by
# an agent or by "System" exactly 72 hours after they were solved, as the job
# would have done.
#
# Refuses to run in production unless DEMO_SEED_IN_PRODUCTION=1 is set.
require "active_support/testing/time_helpers"

module DemoTickets
  extend ActiveSupport::Testing::TimeHelpers

  class NoUsersError < StandardError; end

  # Each step: [hours ago, who, action, argument]
  #   who:    :admin, :first, :second (agents) or :system
  #   action: :create (argument: assignee or nil), :assign (assignee or nil),
  #           :status (new status)
  # The guard avoids a warning when this file is loaded twice, as `bin/rails test`
  # does (test:prepare loads the tasks, then the task tests load them again).
  TICKETS = [
    { subject: "Giriş yapamıyorum, \"geçersiz parola\" hatası alıyorum",
      description: "Bu sabahtan beri panele giriş yapamıyorum. Parolamın doğru olduğundan eminim ama her denemede \"geçersiz parola\" uyarısı çıkıyor.",
      requester_name: "Deniz Arslan", requester_email: "deniz.arslan@example.com", priority: :urgent,
      steps: [ [ 3, :admin, :create, :first ] ] },
    { subject: "Şifre sıfırlama e-postası gelmiyor",
      description: "\"Şifremi unuttum\" bağlantısına üç kez tıkladım, ancak sıfırlama e-postası gelmedi. Spam klasörünü de kontrol ettim.",
      requester_name: "Ece Yıldız", requester_email: "ece.yildiz@example.com", priority: :high,
      steps: [ [ 27, :admin, :create, :first ], [ 25, :first, :status, :pending ] ] },
    { subject: "Kartımdan aynı ödeme iki kez çekildi",
      description: "Aylık abonelik ücreti kredi kartımdan aynı gün iki kez çekildi. Fazla çekilen tutarın iadesini rica ediyorum.",
      requester_name: "Burak Şahin", requester_email: "burak.sahin@example.com", priority: :urgent,
      steps: [ [ 46, :admin, :create, :second ], [ 44, :second, :status, :pending ],
               [ 30, :second, :status, :open ], [ 20, :second, :status, :solved ] ] },
    { subject: "Eylül ayı faturasını talep ediyorum",
      description: "Muhasebe kayıtlarımız için Eylül ayına ait faturanın PDF kopyasını gönderebilir misiniz?",
      requester_name: "Zeynep Koç", requester_email: "zeynep.koc@example.com", priority: :low,
      steps: [ [ 150, :admin, :create, :first ], [ 148, :first, :status, :solved ],
               [ 147, :first, :status, :closed ] ] },
    { subject: "Hesabım kilitlendi, erişim istiyorum",
      description: "Birkaç hatalı denemeden sonra hesabım kilitlendi. Ekip arkadaşlarım da hesabıma bağlı projelere erişemiyor.",
      requester_name: "Kerem Aydın", requester_email: "kerem.aydin@example.com", priority: :high,
      steps: [ [ 1, :admin, :create, nil ] ] },
    { subject: "Raporlar sayfasında \"500 Internal Server Error\"",
      description: "Raporlar sayfasını açtığımda 500 hatası alıyorum. Sorun tüm tarayıcılarda aynı.",
      requester_name: "Selin Çelik", requester_email: "selin.celik@example.com", priority: :high,
      steps: [ [ 9, :admin, :create, :first ], [ 7, :admin, :assign, :second ] ] },
    { subject: "Mobil bildirimler gelmiyor",
      description: "Uygulama güncellemesinden sonra yeni mesaj bildirimleri telefonuma gelmiyor. Bildirim izinleri açık.",
      requester_name: "Emre Kurt", requester_email: "emre.kurt@example.com", priority: :normal,
      steps: [ [ 52, :admin, :create, :second ], [ 50, :second, :status, :pending ] ] },
    { subject: "Özellik talebi: karanlık mod",
      description: "Uzun süre ekran başında çalışıyoruz. Arayüze karanlık mod seçeneği eklenmesini öneriyoruz.",
      requester_name: "Gizem Öztürk", requester_email: "gizem.ozturk@example.com", priority: :low,
      steps: [ [ 70, :admin, :create, nil ] ] },
    { subject: "Kontrol paneli çok yavaş açılıyor",
      description: "Kontrol paneli son iki gündür 20 saniyeden uzun sürede açılıyor. İnternet bağlantımızda sorun yok.",
      requester_name: "Onur Polat", requester_email: "onur.polat@example.com", priority: :high,
      steps: [ [ 12, :admin, :create, :first ], [ 3, :first, :status, :solved ] ] },
    { subject: "Tüm verilerimi CSV olarak dışa aktarmak istiyorum",
      description: "Yıl sonu arşivi için müşteri ve sipariş verilerimizin tamamını CSV olarak dışa aktarmamız gerekiyor.",
      requester_name: "Merve Aksoy", requester_email: "merve.aksoy@example.com", priority: :normal,
      steps: [ [ 110, :admin, :create, :second ], [ 100, :second, :status, :solved ],
               [ 28, :system, :status, :closed ] ] },
    { subject: "İki adımlı doğrulama kodu kabul edilmiyor",
      description: "SMS ile gelen doğrulama kodunu girdiğimde \"kod geçersiz\" uyarısı alıyorum. Telefonumun saati otomatik.",
      requester_name: "Can Yılmaz", requester_email: "can.yilmaz@example.com", priority: :urgent,
      steps: [ [ 40, :admin, :create, :first ], [ 39, :first, :status, :pending ],
               [ 36, :first, :status, :solved ] ] },
    { subject: "Fatura adresimi güncellemek istiyorum",
      description: "Şirketimiz yeni ofise taşındı. Bundan sonraki faturalarda yeni adresin yer almasını istiyoruz.",
      requester_name: "Aslı Demir", requester_email: "asli.demir@example.com", priority: :normal,
      steps: [ [ 6, :admin, :create, :second ] ] },
    { subject: "Mobil uygulama sürekli oturumu kapatıyor",
      description: "Uygulamayı arka plana aldığımda birkaç dakika içinde oturumum kapanıyor ve tekrar giriş yapmam gerekiyor.",
      requester_name: "Tolga Erdem", requester_email: "tolga.erdem@example.com", priority: :normal,
      steps: [ [ 33, :admin, :create, :first ], [ 31, :first, :status, :pending ] ] },
    { subject: "Ödeme sayfası zaman aşımına uğruyor",
      description: "Ödeme adımında \"zaman aşımı\" hatası alıyoruz. Geçen hafta düzelmişti, bugün yeniden başladı.",
      requester_name: "Pelin Güneş", requester_email: "pelin.gunes@example.com", priority: :high,
      steps: [ [ 60, :admin, :create, :second ], [ 55, :second, :status, :solved ],
               [ 5, :admin, :status, :open ], [ 4, :admin, :assign, :first ] ] },
    { subject: "Özellik talebi: e-posta bildirim sıklığı ayarı",
      description: "Her işlem için ayrı e-posta almak yerine günlük özet e-postası seçeneği olmasını istiyoruz.",
      requester_name: "Hakan Toprak", requester_email: "hakan.toprak@example.com", priority: :low,
      steps: [ [ 130, :admin, :create, :first ], [ 120, :first, :status, :solved ],
               [ 48, :system, :status, :closed ] ] },
    { subject: "Yeni ekip üyesine yönetici yetkisi verilmesi",
      description: "Ekibimize katılan arkadaşımızın faturalara ve kullanıcı ayarlarına erişebilmesi için yönetici yetkisi gerekiyor.",
      requester_name: "İrem Başaran", requester_email: "irem.basaran@example.com", priority: :normal,
      steps: [ [ 22, :admin, :create, :second ], [ 15, :second, :status, :solved ] ] },
    { subject: "Arama sonuçları çok geç geliyor",
      description: "Müşteri listesinde arama yaptığımızda sonuçlar 10 saniyeden geç geliyor. Kayıt sayımız yaklaşık 5.000.",
      requester_name: "Barış Kılıç", requester_email: "baris.kilic@example.com", priority: :normal,
      steps: [ [ 18, :admin, :create, nil ], [ 16, :admin, :assign, :first ] ] },
    { subject: "Fatura PDF dosyası açılmıyor",
      description: "E-postayla gelen fatura ekini açtığımda \"dosya bozuk\" uyarısı alıyorum.",
      requester_name: "Nazlı Uçar", requester_email: "nazli.ucar@example.com", priority: :low,
      steps: [ [ 76, :admin, :create, :second ], [ 74, :second, :status, :pending ],
               [ 26, :second, :status, :open ], [ 24, :second, :status, :pending ] ] }
  ].freeze unless const_defined?(:TICKETS, false)

  # Runs the seed. Returns the number of tickets created.
  def self.seed(now: Time.current, out: $stdout)
    users = User.order(:id).to_a
    raise NoUsersError, "No users found. Create an admin first (bin/rails users:create_admin ...)." if users.empty?

    agents = users.select(&:agent?).presence || users
    people = {
      admin: users.find(&:admin?) || users.first,
      first: agents.first,
      second: agents.second || agents.first
    }

    created = 0
    TICKETS.each do |data|
      if Ticket.exists?(subject: data[:subject], requester_email: data[:requester_email])
        out.puts "Skipped (already exists): #{data[:subject]}"
        next
      end

      Ticket.transaction { build(data, people, now) }
      created += 1
      out.puts "Created: #{data[:subject]}"
    end
    created
  end

  def self.build(data, people, now)
    ticket = nil
    data[:steps].each do |hours_ago, who, action, argument|
      actor = who == :system ? nil : people.fetch(who)
      assignee = argument && people[argument]

      travel_to(now - hours_ago.hours) do
        Current.set(session: actor && Session.new(user: actor)) do
          case action
          when :create
            ticket = Ticket.create!(data.slice(:subject, :description, :requester_name, :requester_email, :priority)
                                        .merge(assigned_to: assignee))
          when :assign
            ticket.update!(assigned_to: assignee)
          when :status
            ticket.transition_to(argument.to_s) ||
              raise("#{data[:subject]}: #{ticket.errors.full_messages.to_sentence}")
          end
        end
      end
    end
  end
end

namespace :demo do
  desc "Add example tickets with history for a live demo (safe to run again)"
  task seed: :environment do
    if Rails.env.production? && ENV["DEMO_SEED_IN_PRODUCTION"] != "1"
      abort "Refusing to add demo tickets in production. Set DEMO_SEED_IN_PRODUCTION=1 to do it anyway."
    end

    created = DemoTickets.seed
    puts "#{created} demo ticket(s) created."
  rescue DemoTickets::NoUsersError => e
    abort e.message
  end
end
