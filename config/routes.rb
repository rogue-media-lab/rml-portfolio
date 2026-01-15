Rails.application.routes.draw do
  # User model planned for clients feature
  devise_for :users
  devise_for :milk_admins, skip: [ :registrations ]

  # root for milk admin
  authenticated :milk_admin do
    root to: "milk_admin#dashboard", as: :milk_admin_root
  end

  # Admin Routes
  namespace :milk_admin do
    resource :profile, only: [ :show, :edit, :update ]
    resources :contacts, only: [ :destroy ]
    resources :blog_categories

    # Dashboard routes
    get "blogs/dashboard", to: "blogs#dashboard", as: :blogs_dashboard
    # get "projects/dashboard", to: "projects#dashboard", as: :projects_dashboard
    get "pills/dashboard", to: "pills#dashboard", as: :pills_dashboard
    get "songs/dashboard", to: "songs#dashboard", as: :songs_dashboard
    get "messages/dashboard", to: "messages#dashboard", as: :messages_dashboard

    resources :blogs, only: [ :index, :new, :create, :edit, :update, :destroy ] do
      member do
        delete :destroy_image
      end
    end

    resources :projects, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        delete :destroy_image
      end
      resources :tasks
    end

    resources :songs, only: [ :index, :new, :create, :edit, :update, :destroy ] do
      member do
        delete :destroy_image
        delete :destroy_file
        delete :destroy_banner_video
      end
    end

    resources :playlists do
      member do
        post :add_song
        delete "remove_song/:song_id", action: :remove_song, as: :remove_song
      end
    end

    # SoundCloud Custom Artwork
    resources :custom_sound_cloud_artworks, only: [ :index, :update, :destroy ] do
      collection do
        post :sync  # Sync liked songs from SoundCloud
      end
      member do
        get :customize  # Customize artwork for a specific track
      end
    end

    get "hermit_videos/dashboard", to: "hermit_videos#dashboard", as: :hermit_videos_dashboard
    resources :hermit_videos, only: [ :index, :new, :create, :edit, :update, :destroy ]

    get "hermits/dashboard", to: "hermits#dashboard", as: :hermits_dashboard
    resources :hermits, only: [ :index, :new, :create, :edit, :update, :destroy ]

    resources :pills, only: [ :index, :new, :create, :edit, :update, :destroy ]
  end

  # Public Blog Routes
  resources :blogs, only: [ :index, :show ], controller: "blogs", param: :slug do
    collection do
      get "feature"  # This creates the route for /blogs/feature
      get "categories/:id", action: :index, as: :category # adds category_blogs_path
    end
  end

  # Public Zuke routes
  resources :zuke, only: [ :index ], controller: "zuke" do
    collection do
      get "music", to: "zuke#music", as: :music_list  # This creates the route for /zuke/music
      get "songs", to: "zuke#songs", as: :music_songs  # For turbo frame loading of songs
      get "artists", to: "zuke#artists", as: :music_artists
      get "albums", to: "zuke#albums", as: :music_albums
      get "genres", to: "zuke#genres", as: :music_genres
      get "about", to: "zuke#about", as: :music_about
      get "search", to: "zuke#search", as: :search  # Search across songs, artists, albums
      get "refresh_soundcloud_track/:id", to: "zuke#refresh_soundcloud_track", as: :refresh_soundcloud_track
    end
  end

  # Public Playlists routes (for Zuke music player)
  resources :playlists, only: [ :index, :show ]


  # root for hermits
  get "hermit-plus", to: "hermit_plus#landing", as: :hermits
  # Public Salt and Tar routes
  resources :salt_and_tar, only: [ :index ], path: "salt-and-tar", controller: "salt_and_tar" do
    collection do
      get "archive", to: "salt_and_tar#archive", as: :archive  # /salt-and-tar/archive
    end
  end
  # root for eastbounds
  get "eastbound", to: "eastbounds#index", as: :eastbound
  # root for public route, copywriter
  get "copywriter", to: "copywriter#index", as: :copywriter


  get "info", to: "static_pages#info", as: :info
  get "info/welcome", to: "info#welcome"
  get "info/vibe", to: "info#vibe"
  get "info/skills", to: "info#skills"
  get "info/erudition", to: "info#erudition"

  get "gemini_pro", to: "static_pages#gemini_pro", as: :gemini

  resources :contacts, only: [ :new, :create ]
  resources :projects, only: [ :index ]
  resources :skills, only: [ :index ]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "static_pages#index"
end
