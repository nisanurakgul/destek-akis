# Changes a ticket's status. The allowed moves are defined in Ticket::TRANSITIONS;
# the model rejects anything else, so this controller only reports the result.
class TicketStatusesController < ApplicationController
  def update
    ticket = Ticket.find(params[:ticket_id])
    old_status = ticket.status

    if ticket.transition_to(params.expect(:status))
      redirect_to ticket, notice: "Status changed from #{old_status} to #{ticket.status}."
    else
      redirect_to ticket, alert: ticket.errors.full_messages.to_sentence
    end
  end
end
