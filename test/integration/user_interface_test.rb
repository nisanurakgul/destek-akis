require "test_helper"

# Checks the redesigned (Turkish) interface: layout, navigation, labels and
# that every form and button still points at the same route and HTTP method.
class UserInterfaceTest < ActionDispatch::IntegrationTest
  test "sign-in page has labelled fields, posts to the session and shows no app menu" do
    get new_session_path

    assert_response :success
    assert_select "html[lang=tr]"
    assert_select ".auth-card form[action=?][method=post]", session_path do
      assert_select "label[for=email_address]", "E-posta adresi"
      assert_select "label[for=password]", "Parola"
      assert_select "input[type=submit][value=?]", "Giriş yap"
    end
    assert_select "a[href=?]", new_password_path
    assert_select ".sidebar", count: 0
  end

  test "password reset pages are in Turkish and keep their routes" do
    get new_password_path
    assert_select "form[action=?][method=post]", passwords_path
    assert_select "label[for=email_address]", "E-posta adresi"

    get edit_password_path(users(:agent).password_reset_token)
    assert_select "form[action^=?]", "/passwords/" do
      assert_select "input[name=_method][value=put]"
      assert_select "label[for=password]", "Yeni parola"
      assert_select "label[for=password_confirmation]", "Yeni parola (tekrar)"
    end
  end

  test "agents see the menu without the user management link" do
    sign_in_as users(:agent)
    get tickets_path

    assert_select ".sidebar-nav" do
      assert_select "a[href=?]", root_path, text: "Genel bakış"
      assert_select "a[href=?][aria-current=page]", tickets_path, text: "Talepler"
      assert_select "a[href=?]", users_path, count: 0
    end
    assert_select ".sidebar-user-name", "Ali Agent"
    assert_select ".sidebar-user-role", "Destek temsilcisi"
    assert_select "form[action=?]", session_path do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", "Çıkış yap"
    end
  end

  test "admins see the user management link" do
    sign_in_as users(:admin)
    get users_path

    assert_select ".sidebar-nav a[href=?][aria-current=page]", users_path, text: "Kullanıcılar"
    assert_select ".sidebar-user-role", "Yönetici"
  end

  test "overview shows ticket counts per status and the user's active tickets" do
    sign_in_as users(:agent)
    get root_path

    assert_select ".stat-card", 4
    assert_select ".stat-card", text: /Açık\s*1/
    assert_select ".stat-card", text: /Kapalı\s*1/
    # open_ticket is assigned to the agent; solved_ticket is not active.
    assert_select ".metric-value", "1"
  end

  test "ticket list shows an empty state when there are no tickets" do
    Ticket.destroy_all
    sign_in_as users(:agent)
    get tickets_path

    assert_select "table", count: 0
    assert_select ".empty-state h2", "Henüz talep yok"
    assert_select ".empty-state a[href=?]", new_ticket_path
  end

  test "new ticket form keeps its route and stored values with Turkish labels" do
    sign_in_as users(:agent)
    get new_ticket_path

    assert_select "form[action=?][method=post]", tickets_path do
      assert_select "label[for=ticket_subject]", "Konu"
      assert_select "label[for=ticket_assigned_to_id]", "Atanan kişi"
      assert_select "select[name='ticket[priority]'] option[value=urgent]", "Acil"
      assert_select "select[name='ticket[status]']", count: 0
      assert_select "input[type=submit][value=?]", "Talebi oluştur"
    end
  end

  test "creating and updating a ticket show Turkish notices" do
    sign_in_as users(:agent)

    post tickets_path, params: { ticket: { subject: "Yazıcı çalışmıyor", description: "Kağıt sıkışıyor.",
                                           requester_name: "Selin Koç", requester_email: "selin@example.com",
                                           priority: "low" } }
    follow_redirect!
    assert_select ".flash.notice", "Talep oluşturuldu."

    ticket = Ticket.last
    get edit_ticket_path(ticket)
    assert_select "form[action=?]", ticket_path(ticket) do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[type=submit][value=?]", "Değişiklikleri kaydet"
    end

    patch ticket_path(ticket), params: { ticket: { priority: "high" } }
    follow_redirect!
    assert_select ".flash.notice", "Talep güncellendi."
    assert_select ".badge.priority-high", "Yüksek"
  end

  test "invalid ticket form highlights the fields with errors" do
    sign_in_as users(:agent)
    post tickets_path, params: { ticket: { subject: "", description: "x", requester_name: "A",
                                           requester_email: "a@example.com", priority: "low" } }

    assert_response :unprocessable_entity
    assert_select ".errors h2", /Talep kaydedilemedi/
    assert_select ".field_with_errors input[name='ticket[subject]']"
  end

  test "status buttons send PATCH requests with the target status" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)
    get ticket_path(ticket)

    assert_select ".status-actions form[action=?]", ticket_status_path(ticket), 2
    assert_select ".status-actions form" do
      assert_select "input[name=_method][value=patch]"
    end
    assert_select ".status-actions input[name=status][value=pending]"
    assert_select ".status-actions input[name=status][value=solved]"
  end

  test "solved tickets show when they will be closed automatically" do
    sign_in_as users(:agent)
    ticket = tickets(:solved_ticket)
    get ticket_path(ticket)

    close_at = (ticket.updated_at + Ticket::AUTO_CLOSE_AFTER).strftime("%d.%m.%Y %H:%M")
    assert_select ".inline-note", /#{Regexp.escape(close_at)} sonrasında otomatik olarak kapatılır/
    assert_select ".status-actions button", "Yeniden aç"
    assert_select ".status-actions button", "Kapat"
  end

  test "history shows Sistem for changes made by the background job" do
    ticket = tickets(:solved_ticket)
    travel Ticket::AUTO_CLOSE_AFTER + 1.minute do
      AutoCloseSolvedTicketsJob.perform_now
    end

    sign_in_as users(:agent)
    get ticket_path(ticket)

    assert_select ".history li:last-child .actor", "Sistem"
    assert_select ".history li:last-child .event-description", "Status changed from solved to closed"
  end

  test "user pages are in Turkish and keep their routes" do
    sign_in_as users(:admin)

    get users_path
    assert_select "#user_#{users(:agent).id} .badge.role-agent", "Destek temsilcisi"
    assert_select "#user_#{users(:admin).id} .badge.role-admin", "Yönetici"

    get new_user_path
    assert_select "form[action=?][method=post]", users_path do
      assert_select "label[for=user_name]", "Ad soyad"
      assert_select "select[name='user[role]'] option[value=admin]", "Yönetici"
      assert_select "input[type=submit][value=?]", "Kullanıcıyı oluştur"
    end

    post users_path, params: { user: { name: "Yeni Ajan", email_address: "yeni@example.com", role: "agent",
                                       password: "secret123", password_confirmation: "secret123" } }
    follow_redirect!
    assert_select ".flash.notice", "Yeni Ajan kullanıcısı oluşturuldu."
  end

  test "agents are told in Turkish that user management is for admins" do
    sign_in_as users(:agent)
    get users_path
    follow_redirect!

    assert_select ".flash.alert", "Kullanıcıları yalnızca yöneticiler yönetebilir."
  end
end
