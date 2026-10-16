# Any signed-in user (agent or admin) can work with tickets.
# Signed-out visitors are sent to the sign-in page by the Authentication concern.
class TicketsController < ApplicationController
  before_action :set_ticket, only: %i[ show edit update ]
  before_action :set_assignable_users, only: %i[ new create edit update ]

  def index
    @tickets = Ticket.includes(:assigned_to).order(created_at: :desc)
  end

  def show
    @events = @ticket.events.includes(:user)
  end

  def new
    @ticket = Ticket.new
  end

  def create
    @ticket = Ticket.new(ticket_params)

    if @ticket.save
      redirect_to @ticket, notice: "Talep oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ticket.update(ticket_params)
      redirect_to @ticket, notice: "Talep güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_ticket
      @ticket = Ticket.find(params[:id])
    end

    def set_assignable_users
      @users = User.order(:name)
    end

    # status is not permitted here on purpose: it is changed only through
    # TicketStatusesController, which follows Ticket::TRANSITIONS.
    def ticket_params
      params.expect(ticket: [ :subject, :description, :requester_name, :requester_email,
                              :priority, :assigned_to_id ])
    end
end
