# frozen_string_literal: true

class AddUniqueIndexOnUsersProviderAndUid < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, %i[provider uid],
              unique: true, where: "provider IS NOT NULL", algorithm: :concurrently
  end
end
