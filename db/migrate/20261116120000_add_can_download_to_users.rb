class AddCanDownloadToUsers < ActiveRecord::Migration[8.0]
  def change
    # Gates taking a copy of a song's files.
    #
    # Default false, deliberately: signing up grants an account, not the right to
    # pull masters. Streaming stays public; downloading is granted on purpose.
    add_column :users, :can_download, :boolean, default: false, null: false
  end
end
