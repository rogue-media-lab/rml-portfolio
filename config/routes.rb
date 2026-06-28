Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  # =====================================================================
  # CarUs — Two-sided auto shop + car owner platform
  # =====================================================================
  scope "/carus", module: nil do
    devise_for :car_owners, controllers: {
      registrations: "car_us/registrations"
    }
    devise_for :technicians, skip: [ :registrations ]  # shop-provisioned

    # Public landing page — shop directory
    root to: "car_us/pages#home", as: :carus_root

    # Individual shop landing pages
    resources :shops, only: [ :show ], param: :slug, controller: "car_us/shops", as: :carus_shops

    # Customer routes (authenticated car owners)
    authenticate :car_owner do
      resources :coupons, only: [ :index, :show ], controller: "car_us/coupons"
      resources :services, only: [ :index ], controller: "car_us/services"
      get "rewards", to: "car_us/rewards#index"
    end

    # Manager Portal (authenticated technicians)
    namespace :manager, module: "car_us/manager" do
      root to: "dashboard#index"
      resources :flash_alerts, only: [ :index, :new, :create, :show ]
      resources :customers, only: [ :index ] do
        collection do
          get :search
        end
      end
      resources :services, only: [ :index, :new, :create, :edit, :update, :destroy ]
    end
  end

  # User model planned for clients feature
  devise_for :users
  devise_for :milk_admins, skip: [ :registrations ], controllers: { sessions: "milk_admin/sessions" }

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
    resources :messages, only: [ :show ]

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
    get "hermit_videos/fetch", to: "hermit_videos#fetch", as: :fetch_hermit_videos
    post "hermit_videos/fetch_results", to: "hermit_videos#fetch_results", as: :hermit_videos_fetch_results
    post "hermit_videos/bulk_create", to: "hermit_videos#bulk_create", as: :hermit_videos_bulk_create
    resources :hermit_videos, only: [ :index, :new, :create, :edit, :update, :destroy ]

    get "hermits/dashboard", to: "hermits#dashboard", as: :hermits_dashboard
    resources :hermits, only: [ :index, :new, :create, :edit, :update, :destroy ]

    get "hermit_crews/dashboard", to: "hermit_crews#dashboard", as: :hermit_crews_dashboard
    resources :hermit_crews, only: [ :index, :new, :create, :edit, :update, :destroy ]

    resources :carus_shops, param: :slug, only: [ :index, :show, :new, :create, :edit, :update, :destroy ]

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

  # Hermit Plus App — Season 8
  scope "/hermit-plus" do
    get "/season/8", to: "hermit_seasons#home", as: :hermit_plus_home

    # Hermit roster and profiles
    get "/hermits", to: "hermit_roster#index", as: :hermit_roster
    get "/hermits/:slug", to: "hermit_roster#show", as: :hermit_profile

    # Video browsing
    get "/videos/:id", to: "hermit_videos#show", as: :hermit_video
    get "/watch/:id", to: "hermit_videos#watch", as: :hermit_watch

    # Crews / specials
    get "/crews", to: "hermit_crews#index", as: :hermit_crews
    get "/crews/:slug", to: "hermit_crews#show", as: :hermit_crew

    # User features (require authentication)
    authenticate :user do
      get "/favorites", to: "hermit_favorites#index", as: :hermit_favorites
      post "/favorites/:video_id", to: "hermit_favorites#create"
      delete "/favorites/:video_id", to: "hermit_favorites#destroy"
      patch "/progress/:video_id", to: "hermit_progress#update"
      resource :profile, controller: "user_hermit_profiles", only: [ :show, :edit, :update ], as: :user_hermit_profile
    end
  end

  # Public Salt and Tar routes
  resources :salt_and_tar, only: [ :index ], path: "salt-and-tar", controller: "salt_and_tar" do
    collection do
      get "archive", to: "salt_and_tar#archive", as: :archive  # /salt-and-tar/archive
      get "booking", to: "salt_and_tar#booking", as: :booking  # /salt-and-tar/booking
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
  get "rocky_audio", to: "static_pages#rocky_audio", as: :rocky_audio

  # Rocky AI Assistant
  get  "rocky/chat",   to: "rocky#chat",   as: :rocky_chat
  post "rocky/messages", to: "rocky#create", as: :rocky_messages
  post "rocky/tts",    to: "rocky#tts",    as: :rocky_tts
  get  "rocky/tone",   to: "rocky#tone",   as: :rocky_tone

  # The Studio
  get "studio", to: "studio#index", as: :studio

  # The Lab — Client-facing hire/contact page
  get "lab", to: "lab#index", as: :lab

  resources :contacts, only: [ :new, :create ]
  resources :projects, only: [ :index ]
  resources :skills, only: [ :index ]

  # Restaurant admin (under MilkAdmin) — MUST be before the catch-all scope
  namespace :milk_admin do
    resources :restaurants do
      resources :menu_categories, except: [ :show ]
      resources :menu_items, except: [ :show ]
      resources :testimonials, except: [ :show ]
      resources :hours, only: [ :index, :edit, :update ]
      resources :reservations, only: [ :index, :update, :destroy ]
      resources :orders, only: [ :index, :show, :update, :destroy ]
    end
  end

  # Restaurant platform — multi-tenant restaurant sites
  # These routes MUST come after all specific portfolio routes
  # to avoid slug conflicts with /studio, /lab, /blog, /milk_admin, etc.
  scope "/:restaurant_slug" do
    get "/", to: "restaurants/pages#home", as: :restaurant_home
    get "/menu", to: "restaurants/menu#index", as: :restaurant_menu
    get "/about", to: "restaurants/pages#about", as: :restaurant_about
    get "/contact", to: "restaurants/contact#index", as: :restaurant_contact

    # Cart
    get "/cart", to: "restaurants/cart#show", as: :restaurant_cart
    post "/cart/add", to: "restaurants/cart#add", as: :restaurant_cart_add
    patch "/cart/update", to: "restaurants/cart#update", as: :restaurant_cart_update
    delete "/cart/remove/:menu_item_id", to: "restaurants/cart#remove", as: :restaurant_cart_remove
    delete "/cart/clear", to: "restaurants/cart#clear", as: :restaurant_cart_clear

    # Orders
    get "/orders/new", to: "restaurants/orders#new", as: :new_restaurant_order
    post "/orders", to: "restaurants/orders#create", as: :restaurant_orders
    get "/orders/:id/confirmation", to: "restaurants/orders#confirmation", as: :restaurant_order_confirmation
  end

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
