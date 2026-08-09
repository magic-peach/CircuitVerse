# frozen_string_literal: true

class CreateLtiLaunchNonces < ActiveRecord::Migration[8.1]
  def change
    create_table :lti_launch_nonces do |t|
      t.string :nonce, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :lti_launch_nonces, :nonce, unique: true
  end
end
