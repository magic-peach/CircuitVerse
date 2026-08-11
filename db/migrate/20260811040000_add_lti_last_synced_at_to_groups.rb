# frozen_string_literal: true

class AddLtiLastSyncedAtToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :lti_last_synced_at, :datetime
  end
end
