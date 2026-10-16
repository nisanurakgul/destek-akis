# Closes solved tickets that have not changed for Ticket::AUTO_CLOSE_AFTER (72 hours).
#
# How it works:
#   1. Find solved tickets whose updated_at is at least 72 hours ago.
#   2. For each one, lock and reload the row, then check again: if someone
#      reopened or edited it in the meantime, leave it alone.
#   3. Close it with transition_to("closed"), so the normal status rules apply.
#
# Scheduled every hour in production by config/recurring.yml. To run it by hand:
#   bin/rails runner "AutoCloseSolvedTicketsJob.perform_now"
class AutoCloseSolvedTicketsJob < ApplicationJob
  queue_as :default

  # Returns the number of tickets that were closed.
  def perform(now = Time.current)
    closed_count = 0

    candidates(now).find_each do |ticket|
      ticket.with_lock do
        # with_lock reloaded the ticket, so this sees the latest saved data.
        next unless ticket.solved? && ticket.updated_at <= now - Ticket::AUTO_CLOSE_AFTER

        if ticket.transition_to("closed")
          closed_count += 1
        else
          Rails.logger.warn("Auto-close skipped ticket ##{ticket.id}: #{ticket.errors.full_messages.to_sentence}")
        end
      end
    end

    closed_count
  end

  private
    # Separate method so tests can simulate a ticket that changed after this query ran.
    def candidates(now)
      Ticket.ready_to_auto_close(now)
    end
end
