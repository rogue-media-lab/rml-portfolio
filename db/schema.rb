# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_26_170114) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "albums", force: :cascade do |t|
    t.string "title"
    t.integer "release_year"
    t.bigint "genre_id"
    t.bigint "artist_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_albums_on_artist_id"
    t.index ["genre_id"], name: "index_albums_on_genre_id"
    t.index ["title", "artist_id"], name: "index_albums_on_title_and_artist_id", unique: true
  end

  create_table "artists", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_artists_on_name", unique: true
  end

  create_table "blog_categories", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "blogs", force: :cascade do |t|
    t.string "title"
    t.string "subtitle"
    t.datetime "published_at"
    t.bigint "milk_admin_id", null: false
    t.bigint "blog_category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "processed_body"
    t.string "slug"
    t.boolean "featured", default: false, null: false
    t.integer "views_count", default: 0, null: false
    t.index ["blog_category_id"], name: "index_blogs_on_blog_category_id"
    t.index ["featured"], name: "index_blogs_on_featured", unique: true, where: "(featured IS TRUE)"
    t.index ["milk_admin_id"], name: "index_blogs_on_milk_admin_id"
    t.index ["slug"], name: "index_blogs_on_slug", unique: true
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_session_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.integer "input_tokens", default: 0
    t.integer "output_tokens", default: 0
    t.decimal "cost_usd", default: "0.0"
    t.string "media_type"
    t.string "media_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_session_id"], name: "index_chat_messages_on_chat_session_id"
  end

  create_table "chat_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_chat_sessions_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "f_name"
    t.string "l_name"
    t.string "email"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
  end

  create_table "custom_sound_cloud_artworks", force: :cascade do |t|
    t.string "soundcloud_track_id"
    t.string "track_title"
    t.string "track_artist"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["soundcloud_track_id"], name: "index_custom_sound_cloud_artworks_on_soundcloud_track_id", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "hermit_video_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hermit_video_id"], name: "index_favorites_on_hermit_video_id"
    t.index ["user_id", "hermit_video_id"], name: "index_favorites_on_user_id_and_hermit_video_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "genres", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_genres_on_name", unique: true
  end

  create_table "hermit_appearances", force: :cascade do |t|
    t.bigint "hermit_video_id", null: false
    t.bigint "hermit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hermit_id"], name: "index_hermit_appearances_on_hermit_id"
    t.index ["hermit_video_id"], name: "index_hermit_appearances_on_hermit_video_id"
  end

  create_table "hermit_crew_memberships", force: :cascade do |t|
    t.bigint "hermit_crew_id", null: false
    t.bigint "hermit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hermit_crew_id"], name: "index_hermit_crew_memberships_on_hermit_crew_id"
    t.index ["hermit_id"], name: "index_hermit_crew_memberships_on_hermit_id"
  end

  create_table "hermit_crews", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "image_url"
    t.integer "season", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_hermit_crews_on_slug", unique: true
  end

  create_table "hermit_videos", force: :cascade do |t|
    t.string "youtube_video_id"
    t.string "thumbnail_url"
    t.string "title"
    t.integer "season"
    t.integer "episode"
    t.bigint "hermit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hermit_id"], name: "index_hermit_videos_on_hermit_id"
  end

  create_table "hermits", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "alias"
    t.string "alias_image_alt"
    t.string "nick_name"
    t.float "subs"
    t.string "quote"
    t.string "youtube"
    t.string "twitch"
    t.string "twitter"
    t.string "instagram"
    t.string "patreon"
    t.string "skin_alt"
    t.string "face_alt"
    t.string "avatar_url"
    t.string "banner_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "alias_image_url"
    t.string "from"
    t.string "skin_url"
    t.string "face_url"
    t.text "info2"
    t.string "slug"
    t.index ["slug"], name: "index_hermits_on_slug", unique: true
  end

  create_table "hours", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.integer "day_of_week", null: false
    t.time "open_time"
    t.time "close_time"
    t.boolean "closed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_hours_on_restaurant_id"
  end

  create_table "menu_categories", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_menu_categories_on_restaurant_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.bigint "menu_category_id", null: false
    t.bigint "restaurant_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 8, scale: 2, null: false
    t.boolean "active", default: true
    t.boolean "featured", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_category_id"], name: "index_menu_items_on_menu_category_id"
    t.index ["restaurant_id"], name: "index_menu_items_on_restaurant_id"
  end

  create_table "milk_admin_profiles", force: :cascade do |t|
    t.bigint "milk_admin_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.text "bio"
    t.json "social_links"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["milk_admin_id"], name: "index_milk_admin_profiles_on_milk_admin_id"
  end

  create_table "milk_admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_milk_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_milk_admins_on_reset_password_token", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "menu_item_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_item_id"], name: "index_order_items_on_menu_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "customer_name", null: false
    t.string "phone", null: false
    t.time "pickup_time"
    t.decimal "total", precision: 8, scale: 2, null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_orders_on_restaurant_id"
  end

  create_table "pills", force: :cascade do |t|
    t.string "skill"
    t.string "version"
    t.string "version_color"
    t.bigint "resume_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "group"
    t.index ["resume_id"], name: "index_pills_on_resume_id"
  end

  create_table "playlist_songs", force: :cascade do |t|
    t.bigint "playlist_id", null: false
    t.bigint "song_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id", "song_id"], name: "index_playlist_songs_on_playlist_id_and_song_id", unique: true
    t.index ["playlist_id"], name: "index_playlist_songs_on_playlist_id"
    t.index ["position"], name: "index_playlist_songs_on_position"
    t.index ["song_id"], name: "index_playlist_songs_on_song_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_playlists_on_name"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "code_url"
    t.string "design_url"
    t.string "live_url"
    t.bigint "resume_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "short_title"
    t.text "short_description"
    t.boolean "featured", default: false, null: false
    t.index ["resume_id"], name: "index_projects_on_resume_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "customer_name", null: false
    t.string "phone", null: false
    t.integer "party_size", null: false
    t.date "reservation_date", null: false
    t.time "reservation_time", null: false
    t.text "special_requests"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_reservations_on_restaurant_id"
  end

  create_table "restaurants", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "tagline"
    t.string "address"
    t.string "phone"
    t.string "email"
    t.string "place_id"
    t.decimal "rating", precision: 2, scale: 1
    t.integer "review_count", default: 0
    t.string "price_level"
    t.string "service_type"
    t.string "primary_color", default: "#FDD835"
    t.string "accent_color", default: "#A10035"
    t.string "dark_color", default: "#1A237E"
    t.string "font_display", default: "Lilita One"
    t.string "font_body", default: "Nunito"
    t.string "hero_image"
    t.string "logo_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_restaurants_on_slug", unique: true
  end

  create_table "resumes", force: :cascade do |t|
    t.string "title"
    t.string "full_name"
    t.string "addr"
    t.string "citystatezip"
    t.string "email"
    t.string "linkedin"
    t.string "code_1"
    t.string "code_2"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rock_pets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "level", default: 1
    t.integer "xp", default: 0
    t.integer "xp_to_next_level", default: 100
    t.string "stage", default: "egg"
    t.jsonb "personality_attributes", default: {}
    t.jsonb "skills_learned", default: []
    t.jsonb "achievements", default: []
    t.integer "total_messages", default: 0
    t.integer "total_conversations", default: 0
    t.integer "total_words", default: 0
    t.datetime "last_interaction_at"
    t.string "nickname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_rock_pets_on_level"
    t.index ["stage"], name: "index_rock_pets_on_stage"
    t.index ["user_id"], name: "index_rock_pets_on_user_id"
  end

  create_table "salt_and_tar_videos", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "video_url"
    t.string "thumbnail_url"
    t.integer "position"
    t.boolean "published", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "youtube_url"
    t.index ["published"], name: "index_salt_and_tar_videos_on_published"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "song_genres", force: :cascade do |t|
    t.bigint "song_id", null: false
    t.bigint "genre_id", null: false
    t.index ["genre_id"], name: "index_song_genres_on_genre_id"
    t.index ["song_id"], name: "index_song_genres_on_song_id"
  end

  create_table "songs", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "artist_id", null: false
    t.bigint "album_id"
    t.float "focal_point_x", default: 0.5
    t.float "focal_point_y", default: 0.5
    t.string "image_credit"
    t.string "image_credit_url"
    t.string "image_license"
    t.string "audio_source"
    t.string "audio_license"
    t.text "additional_credits"
    t.index ["album_id"], name: "index_songs_on_album_id"
    t.index ["artist_id"], name: "index_songs_on_artist_id"
  end

  create_table "songs_users", id: false, force: :cascade do |t|
    t.bigint "song_id", null: false
    t.bigint "user_id", null: false
    t.index ["song_id", "user_id"], name: "index_songs_users_on_song_id_and_user_id"
    t.index ["user_id", "song_id"], name: "index_songs_users_on_user_id_and_song_id"
  end

  create_table "soundcloud_tokens", force: :cascade do |t|
    t.text "access_token"
    t.text "refresh_token"
    t.integer "expires_at"
    t.string "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "status"
    t.integer "estimated_time"
    t.boolean "completed"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_tasks_on_project_id"
  end

  create_table "testimonials", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "customer_name", null: false
    t.text "quote", null: false
    t.integer "stars", default: 5
    t.boolean "active", default: true
    t.boolean "featured", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_testimonials_on_restaurant_id"
  end

  create_table "tones", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "tags", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_hermit_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "waitlist_status", default: "pending"
    t.bigint "favorite_hermit_id"
    t.boolean "notifications_enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["favorite_hermit_id"], name: "index_user_hermit_profiles_on_favorite_hermit_id"
    t.index ["user_id"], name: "index_user_hermit_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "watch_progresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "hermit_video_id", null: false
    t.integer "progress_seconds", default: 0
    t.boolean "completed", default: false
    t.datetime "last_watched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hermit_video_id"], name: "index_watch_progresses_on_hermit_video_id"
    t.index ["user_id", "hermit_video_id"], name: "index_watch_progresses_on_user_id_and_hermit_video_id", unique: true
    t.index ["user_id"], name: "index_watch_progresses_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "albums", "artists"
  add_foreign_key "albums", "genres"
  add_foreign_key "blogs", "blog_categories"
  add_foreign_key "blogs", "milk_admins"
  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "users"
  add_foreign_key "favorites", "hermit_videos"
  add_foreign_key "favorites", "users"
  add_foreign_key "hermit_appearances", "hermit_videos"
  add_foreign_key "hermit_appearances", "hermits"
  add_foreign_key "hermit_crew_memberships", "hermit_crews"
  add_foreign_key "hermit_crew_memberships", "hermits"
  add_foreign_key "hermit_videos", "hermits"
  add_foreign_key "hours", "restaurants"
  add_foreign_key "menu_categories", "restaurants"
  add_foreign_key "menu_items", "menu_categories"
  add_foreign_key "menu_items", "restaurants"
  add_foreign_key "milk_admin_profiles", "milk_admins"
  add_foreign_key "order_items", "menu_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "restaurants"
  add_foreign_key "pills", "resumes"
  add_foreign_key "playlist_songs", "playlists"
  add_foreign_key "playlist_songs", "songs"
  add_foreign_key "projects", "resumes"
  add_foreign_key "reservations", "restaurants"
  add_foreign_key "rock_pets", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "song_genres", "genres"
  add_foreign_key "song_genres", "songs"
  add_foreign_key "songs", "albums"
  add_foreign_key "songs", "artists"
  add_foreign_key "tasks", "projects"
  add_foreign_key "testimonials", "restaurants"
  add_foreign_key "user_hermit_profiles", "hermits", column: "favorite_hermit_id"
  add_foreign_key "user_hermit_profiles", "users"
  add_foreign_key "watch_progresses", "hermit_videos"
  add_foreign_key "watch_progresses", "users"
end
