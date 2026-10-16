# Signed-in landing page: a short overview of the ticket counts and quick links.
class HomeController < ApplicationController
  def index
    @status_counts = Ticket.group(:status).count
    @my_active_count = Ticket.where(assigned_to: Current.user, status: %w[open pending]).count
  end
end
