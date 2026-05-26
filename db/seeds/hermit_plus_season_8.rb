require "json"

# =============================================================================
# Hermit Plus Season 8 — Seed Data
# =============================================================================
# Sources:
#   - /home/masonroberts/projects/hermit-test/hermits/client/src/data/hermits.json
#   - /home/masonroberts/projects/hermit-test/hermits/client/src/data/vidCards.json
#   - /home/masonroberts/projects/hermit-test/hermits/client/src/data/videos.js
# =============================================================================

puts "--- Seeding Hermit Plus Season 8 ---"

# ============================================================================
# 1. HERMITS — Full data from React hermits.json + manual hermit list
# ============================================================================

# Detailed hermit profiles from React hermits.json
DETAILED_HERMIT_DATA = [
  {
    alias: "bdouble100", nick_name: "bdubs", first_name: "John", last_name: "Booko",
    alias_image_url: "/images/bdubsInfoBannerText.png", alias_image_alt: "B dubs info banner",
    subs: "1.73M", quote: "Gotta Shweep",
    info_text: "Bdouble0100, otherwise known as Bdouble0 or Bdubs, has been a hermit since 2013 when he joined up in season 5. Part of the B-Team, and NHO, Bdubs had a great season. He really took to the jungle and built an amazing tree with a massive glass dome. His builds are just as impressive as the mayhem he brings. An amazing builder who is always up for anything. He has an obsession with sleeping at dusk and always knows the time.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://m.youtube.com/c/bdoubleo", twitch: "https://www.twitch.tv/BdoubleO100",
    twitter: "https://twitter.com/BdoubleO100", instagram: "https://www.instagram.com/bdoubleoinsta/",
    patreon: "https://www.patreon.com/BdoubleO100",
    skin_url: "/images/bdouble_minecraft_skin.png", skin_alt: "B dubs minecraft skin",
    face_url: "/images/BdoubleO100-face.png", face_alt: "That big eye, anime face we love",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLQS_kfkNT9Sq16v8aFJhEDE65vjCYNy9s0DjT5zGg=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/DDJtPbS0-zNuZp1Bgq3qD9XKr0Dw22q4IIGM8HtRkYc6cEd6wTwMSoj9BG_T3xj9YURqND6EwV8=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Michigan, USA"
  },
  {
    alias: "cubfan", nick_name: "cub", first_name: "", last_name: "",
    alias_image_url: "", alias_image_alt: "cub fan 1 35",
    subs: "818K", quote: "praise beef",
    info_text: "In season 8 cub has taken to the one of the new blocks, the stalactite and has set up a farm. He is using them to build a very unique and interesting terrain that is other worldly. He is a true Minecraft nerd and hosts a series all about things you didn't know in Minecraft. He has been a Hermit since season 4.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/cubfan135", twitch: "https://twitch.tv/cubfan135",
    twitter: "https://twitter.com/cubfan135", instagram: "https://instagram.com/cubfan135",
    patreon: "",
    skin_url: "/images/Cubfan135-Scientist-skin.png", skin_alt: "cub fan mine craft skin",
    face_url: "/images/Cubfan135-face.png", face_alt: "cub fan mine craft face",
    avatar_url: "https://yt3.ggpht.com/iT0tm3p2uzfBHKOtytn2fP_Xx237QCnggqNVR4FRYv5-GXU0lgk9gfufiTVFmp5WIVamTG4g=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/3XDTlZVizPU0-kR8bugCuKuRMP8VLvWNzofIL2k8QpUQ3q410tbFk1FXA8Z7USr-ZBqQWqsNaQ=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Michigan, USA"
  },
  {
    alias: "docm77", nick_name: "doc", first_name: "", last_name: "",
    alias_image_url: "", alias_image_alt: "doc m 77",
    subs: "900K", quote: "",
    info_text: "Docm77, known for short as Docm or Doc, is a YouTuber and an active Hermit on the Hermitcraft server. He played during Seasons 3, 4, 5, 6, 7, and 8. He has 900,000 subscribers",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/docm77", twitch: "https://twitch.tv/docm77live",
    twitter: "https://twitter.com/docm77", instagram: "https://instagram.com/docm77",
    patreon: "",
    skin_url: "/images/Docm77-0_skin.png", skin_alt: "doc's mine craft skin",
    face_url: "/images/Doc-face.png", face_alt: "doc's mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLSrl6fyVjFOR8PmQ74579KoEMOUOWvUE6Y1Oqqm=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/ZH3DeCHaXgC7u5h3TpPHKzpwTOmXWOYi1zQO2ri8_wUJ2p-MOSQEwGFYONKNyL-UsHsEncNGHg=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Baden-Wurttemberg, Germany"
  },
  {
    alias: "ethoslab", nick_name: "etho", first_name: "", last_name: "",
    alias_image_url: "", alias_image_alt: "E though",
    subs: "2.3M", quote: "",
    info_text: "EthosLab, known for short as Etho, is an active Hermit who joined in Season 3, and has been active in every Season since, except for Season 6, where he did not play. He is a long-time prolific member of the Minecraft community, having commonly used redstone techniques, and even a block (named the Etho Slab) in 2013's joke Java Edition 2.0 named after his channel. EthosLab is part of the NHO with Docm77, BdoubleO100, and VintageBeef. He and VintageBeef are also members of Team Canada with PauseUnpause, a non-Hermit. He currently has 2,330,000 subscribers.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/EthosLab", twitch: "https://twitch.tv/EthoTV",
    twitter: "https://twitter.com/EthoLP", instagram: "",
    patreon: "",
    skin_url: "/images/etho_minecraft_skin.png", skin_alt: "etho's mine craft skin",
    face_url: "/images/Etho-face.png", face_alt: "etho's mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLR5GmjkDFqJc7OR0KLSUMaRO9uSglHog1f2rJjL=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/kYMGYUFhrt_-BBZFwR8YgK1ZGvGJkojhLZEOu_op2fwQMTuPMl40NvGACQ3kUtkVd3kyqOsv=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Canada"
  },
  {
    alias: "geminitay", nick_name: "GeminiTay", first_name: "Taylor", last_name: "",
    alias_image_url: "", alias_image_alt: "GeminiTay",
    subs: "1.1M", quote: "I'm chaffed to bits.",
    info_text: "GeminiTay, known as Gemini or Gem for short, is a YouTuber and an active member of the Hermitcraft server. She has 1,130,000 subscribers and has been a member since Season 8.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/GeminiTard", twitch: "https://twitch.tv/GeminiTay",
    twitter: "https://twitter.com/GeminiTayMC", instagram: "https://instagram.com/geminitay",
    patreon: "",
    skin_url: "/images/gemini_minecraft_skin.png", skin_alt: "gem's mine craft skin",
    face_url: "/images/GeminiTay-face.png", face_alt: "gem's mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLTFDpX-t9IbIXuBAsdlVfPMOJlij5F92tZY26oZoQ=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/UDIFE6xsRI8QDC7m4KnRmDG6jHYk8TO0XQ8uMmnMiGyTU-neRgvonZcsz1Gy_Uvw4zA0Ysha=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Newfoundland, Canada"
  },
  {
    alias: "goodtimeswithscar", nick_name: "Good Times With Scar", first_name: "Ryan", last_name: "",
    alias_image_url: "", alias_image_alt: "scar",
    subs: "1.6M", quote: "I'm chaffed to bits.",
    info_text: "GoodTimesWithScar, also known as Scar for short and GoodTimeWithScar on Minecraft, is a YouTuber with over 1,660,000 subscribers. He is known as an excellent terraformer among the Hermits. He is also known for his love of his cat, Jellie, who has been added as a skin for cats in the 1.14 Java Edition update.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/GoodTimesWithScar", twitch: "https://twitch.tv/goodtimeswithscar",
    twitter: "https://twitter.com/GTWScar", instagram: "https://instagram.com/goodtimeswithscar",
    patreon: "",
    skin_url: "/images/scar_minecraft_skin.png", skin_alt: "scar's mine craft skin",
    face_url: "/images/Scar-face.png", face_alt: "scar's mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLR2uOpFcN-OV3MFZkm5HtBn7wDha-O7URtBaj1uSQ=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/NewgK80uJxdGGLjYJgKEUbM0qH7fLIgKjK_gJLBsR5_WcxqLt8-SNeL72Cgs5vIgBKXxtDlYsA=w1707-fcrop64=1,00005a57ffffa8-k-c0xffffffff-no-nd-rj",
    from_place: "Washington, USA"
  },
  {
    alias: "joehills", nick_name: "joehills", first_name: "Joseph Benedict", last_name: "Hills Jr.",
    alias_image_url: "", alias_image_alt: "Joe Hills",
    subs: "147K", quote: "Tiiiiime skip!",
    info_text: "JoeHills, known for short as Joe, joined Hermitcraft in May 2012 in the fifth week of Season 1 and is currently active. He is one of five people who have been involved in Hermitcraft since Season 1, the others being BdoubleO100, Hypnotizd, Keralis, and XisumaVoid. He has 147,000 subscribers on his channel, JoeHillsTSD. JoeHills joined YouTube on June 26, 2011, and started uploading Minecraft Super Hostile Series before being invited to Hermitcraft.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/JoeHillsTSD", twitch: "https://twitch.tv/JoeHills",
    twitter: "https://twitter.com/joehills", instagram: "https://instagram.com/joehillstsd",
    patreon: "",
    skin_url: "/images/JoeHills_minecraft_skin.png", skin_alt: "joe hills mine craft skin",
    face_url: "/images/JoeHills-face.png", face_alt: "joehills mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLQr6mAOxcFg1yIhBUF3ShqUM-2Q_E1YkbNi1KBf=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/2ta_7MBbNmn8XEetviGrZdhDQwrNGZAMinQx8PY_eLOSD4mWlZjeJLaZ0Nl6UAKjTXBrPPwO=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Nashville, USA"
  },
  {
    alias: "keralis", nick_name: "keralis", first_name: "Arek Roman", last_name: "Lisowski",
    alias_image_url: "", alias_image_alt: "ker a lis",
    subs: "2.3M", quote: "Look into my eyes, nothing but eyes",
    info_text: "Keralis is a YouTuber and member of the Hermitcraft server. He joined the server in Season 1 and has amassed 2,340,000 subscribers on his YouTube channel. He is known for his building skills, and his numerous building tutorials.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/Keralis", twitch: "https://twitch.tv/keralis",
    twitter: "https://twitter.com/WorldofKeralis", instagram: "https://instagram.com/iamkeralis",
    patreon: "",
    skin_url: "/images/keralis_minecraft_skin.png", skin_alt: "keralis mine craft skin",
    face_url: "/images/Keralis-face.png", face_alt: "keralis mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLTccJlrZjf-XHZ348Bc56RYh0YuCLEAYfkap1X0TA=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/ny0aVNOl4Eoixvnp93dzKihpilByzed8r-Of986emS_FhXAg-gRoGXW-kkueh7vsJ6KZH8lHRw=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Sweden"
  },
  {
    alias: "tangotek", nick_name: "Tango Tek", first_name: "", last_name: "",
    alias_image_url: "", alias_image_alt: "Tango Tech",
    subs: "1M", quote: "",
    info_text: "TangoTek, known as Tango for short, is a Hermit who was whitelisted in Season 2 for a day in November 2013 and later officially joined in July of 2014 during the same season. He is currently active. Along with ZedaphPlays and ImpulseSV, he is a member of Team ZIT. He has recently reached 1M subscribers. TangoTek also has a second channel, Tango Tek2, where he uploads livestreams.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/TangoTekLP", twitch: "https://twitch.tv/tangotek",
    twitter: "https://twitter.com/TangoTekLP", instagram: "",
    patreon: "",
    skin_url: "/images/Big_Eye_TangoTek_skin.png", skin_alt: "tango tek mine craft skin",
    face_url: "/images/TangoTek-face.png", face_alt: "Tango Tek mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLSz2R7xKZtt4T0a0mq5CMQYE6AP0k1EeZJgGmq0pQ=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/rl5YmRrZkRXiSZNJM-I0D1lXUqRWXYd9DfUr8cqLd9xo0VjVCnO3SmzBGXxSav8FhUNTKHbZ=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "Arizona, USA"
  },
  {
    alias: "zombiecleo", nick_name: "ZombieCleo", first_name: "", last_name: "",
    alias_image_url: "", alias_image_alt: "ZombieCleo",
    subs: "278K", quote: "class dismissed",
    info_text: "ZombieCleo, known as Cleo for short, is a YouTuber and member of the Hermitcraft server. She joined at the start of Season 2 after being invited by JoeHills. She has amassed 278,000 subscribers on her YouTube channel, which she started in June of 2011.",
    info2: "This application currently only displays the youtube content so please be sure to visit the channel and like, comment and subscribe to your favorite video's. Also be sure to visit the Patreon and see all the good things you can get!",
    youtube: "https://www.youtube.com/user/zombiecleo", twitch: "https://twitch.tv/zombiecleo",
    twitter: "https://twitter.com/ZombieCleo", instagram: "",
    patreon: "",
    skin_url: "/images/ZombieCleo_minecraft_skin.png", skin_alt: "zombie cleo mine craft skin",
    face_url: "/images/ZombieCleo-face.png", face_alt: "zombie cleo mine craft face",
    avatar_url: "https://yt3.ggpht.com/ytc/AKedOLRUnid3bbqdUWBAJrrUaNayiQxrFhZyM0mNB1s1=s88-c-k-c0x00ffffff-no-rj",
    banner_url: "https://yt3.googleusercontent.com/yeUOHXbPY7yPAFOsGmSAAAqagCL-FykHUaM82AsPOZ4HPo-g0dZYHWx4TE8yv__ln8yBCRVigOs=w1707-fcrop64=1,00005a57ffffa5a8-k-c0xffffffff-no-nd-rj",
    from_place: "British, UK"
  }
].freeze

# Remaining Season 8 hermits (minimal data — populated with known public info)
MINIMAL_HERMIT_DATA = [
  { alias: "falsesymmetry", nick_name: "FalseSymmetry", from_place: "United Kingdom" },
  { alias: "grian", nick_name: "Grian", from_place: "United Kingdom" },
  { alias: "hypnotizd", nick_name: "Hypnotizd", from_place: "United States" },
  { alias: "ijevin", nick_name: "iJevin", from_place: "United States" },
  { alias: "impulsesv", nick_name: "ImpulseSV", from_place: "United States" },
  { alias: "iskall85", nick_name: "Iskall85", from_place: "Sweden" },
  { alias: "mumbo", nick_name: "MumboJumbo", from_place: "United Kingdom" },
  { alias: "pearl", nick_name: "PearlescentMoon", from_place: "New Zealand" },
  { alias: "rendog", nick_name: "Rendog", from_place: "South Africa" },
  { alias: "stressmonster", nick_name: "Stressmonster101", from_place: "United Kingdom" },
  { alias: "tinfoilchef", nick_name: "TinFoilChef", from_place: "United States" },
  { alias: "vintagebeef", nick_name: "VintageBeef", from_place: "Canada" },
  { alias: "welsknight", nick_name: "Welsknight", from_place: "United States" },
  { alias: "xbcrafted", nick_name: "xBCrafted", from_place: "United States" },
  { alias: "xisumavoid", nick_name: "Xisumavoid", from_place: "United Kingdom" },
  { alias: "zedaphplays", nick_name: "Zedaph", from_place: "United Kingdom" }
].freeze

# ============================================================================
# 2. CREWS — From React videos.js specials
# ============================================================================

CREWS = [
  {
    name: "Boat'em Crew",
    slug: "boatem-crew",
    description: "Grian, Mumbo, Scar, Impulse, and Pearl found each other in the same place. Boats were stacked into a totem because, boats!",
    image_url: "/images/boatem_crew.png",
    season: 8,
    member_aliases: %w[grian mumbo goodtimeswithscar impulsesv pearl]
  },
  {
    name: "Big Eye Crew",
    slug: "big-eye-crew",
    description: "The time king, BDouble0, the trouble maker, Keralis, and the Iron king, Tango find themselves the perfect italian cove.",
    image_url: "/images/big-eye-crew.png",
    season: 8,
    member_aliases: %w[bdouble100 keralis tangotek]
  },
  {
    name: "The Goats Return",
    slug: "the-goats-return",
    description: "They fly in, in a RV and this season they are not playing around. From finding the mutha of all chunks to bringing the lightening, this will be fun!",
    image_url: "/images/doc-dog.png",
    season: 8,
    member_aliases: %w[docm77 ethoslab vintagebeef]
  },
  {
    name: "The Swamp",
    slug: "the-swamp",
    description: "False, Stress, Gem, and iJevin have surrounded the swamp. The transformation is something to behold!",
    image_url: "/images/swamp-crew.png",
    season: 8,
    member_aliases: %w[falsesymmetry stressmonster geminitay ijevin]
  }
].freeze

# ============================================================================
# 3. SAMPLE VIDEOS — Episode 1 for each hermit (from vidCards.json)
# ============================================================================

SAMPLE_VIDEOS = [
  # bdouble0
  { alias: "bdouble100", episode: 1, season: 8, youtube_video_id: "JK7tfMkMYmQ",
    title: "Hermitcraft, S8 E1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/JK7tfMkMYmQ/hqdefault.jpg",
    description: "Minecraft time on the Hermitcraft Server Season 8 SMP Episode 1! Today on the Hermitcraft Minecraft SMP, we start a brand new adventure in a brand new world with a very old set of friends." },
  # cubfan
  { alias: "cubfan", episode: 1, season: 8, youtube_video_id: "X7ZqGjP-wHU",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/X7ZqGjP-wHU/hqdefault.jpg",
    description: "" },
  # docm77
  { alias: "docm77", episode: 1, season: 8, youtube_video_id: "rYxOIfgWUks",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/rYxOIfgWUks/hqdefault.jpg",
    description: "" },
  # ethoslab
  { alias: "ethoslab", episode: 1, season: 8, youtube_video_id: "wWHhzqGP_Z0",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/wWHhzqGP_Z0/hqdefault.jpg",
    description: "" },
  # falsesymmetry
  { alias: "falsesymmetry", episode: 1, season: 8, youtube_video_id: "fjbM8B0O_-o",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/fjbM8B0O_-o/hqdefault.jpg",
    description: "" },
  # geminitay
  { alias: "geminitay", episode: 1, season: 8, youtube_video_id: "6uY4CNKNHQ4",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/6uY4CNKNHQ4/hqdefault.jpg",
    description: "" },
  # goodtimeswithscar
  { alias: "goodtimeswithscar", episode: 1, season: 8, youtube_video_id: "ggRPnFuu-Qs",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/ggRPnFuu-Qs/hqdefault.jpg",
    description: "" },
  # grian
  { alias: "grian", episode: 1, season: 8, youtube_video_id: "mugNnLkEgT8",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/mugNnLkEgT8/hqdefault.jpg",
    description: "" },
  # hypnotizd
  { alias: "hypnotizd", episode: 1, season: 8, youtube_video_id: "_OBzQq2_myo",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/_OBzQq2_myo/hqdefault.jpg",
    description: "" },
  # ijevin
  { alias: "ijevin", episode: 1, season: 8, youtube_video_id: "0GIRcMB4is8",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/0GIRcMB4is8/hqdefault.jpg",
    description: "" },
  # impulsesv
  { alias: "impulsesv", episode: 1, season: 8, youtube_video_id: "v346IR6AqFI",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/v346IR6AqFI/mqdefault.webp",
    description: "" },
  # iskall85
  { alias: "iskall85", episode: 1, season: 8, youtube_video_id: "giLuKkTahRU",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/giLuKkTahRU/mqdefault.webp",
    description: "" },
  # joehills
  { alias: "joehills", episode: 1, season: 8, youtube_video_id: "IPyLUU9Dano",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/IPyLUU9Dano/mqdefault.webp",
    description: "" },
  # keralis
  { alias: "keralis", episode: 1, season: 8, youtube_video_id: "0fyzQELXeJI",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/0fyzQELXeJI/mqdefault.webp",
    description: "" },
  # mumbo
  { alias: "mumbo", episode: 1, season: 8, youtube_video_id: "VTQOZQbJfU4",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/VTQOZQbJfU4/mqdefault.jpg",
    description: "" },
  # pearl
  { alias: "pearl", episode: 1, season: 8, youtube_video_id: "HIVv5TLrf8g",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/HIVv5TLrf8g/mqdefault.webp",
    description: "" },
  # rendog
  { alias: "rendog", episode: 1, season: 8, youtube_video_id: "s-k45J8EBXQ",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/s-k45J8EBXQ/mqdefault.jpg",
    description: "" },
  # stressmonster
  { alias: "stressmonster", episode: 1, season: 8, youtube_video_id: "zoa6HF7wBgw",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/zoa6HF7wBgw/mqdefault.webp",
    description: "" },
  # tangotek
  { alias: "tangotek", episode: 1, season: 8, youtube_video_id: "EUlEwChz3ak",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/EUlEwChz3ak/mqdefault.webp",
    description: "" },
  # tinfoilchef
  { alias: "tinfoilchef", episode: 1, season: 8, youtube_video_id: "A1yBK9qY9Gs",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/A1yBK9qY9Gs/mqdefault.jpg",
    description: "" },
  # vintagebeef
  { alias: "vintagebeef", episode: 1, season: 8, youtube_video_id: "CemJGgXIiQg",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/CemJGgXIiQg/mqdefault.jpg",
    description: "" },
  # welsknight
  { alias: "welsknight", episode: 1, season: 8, youtube_video_id: "OUSLnmDg35c",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/OUSLnmDg35c/mqdefault.jpg",
    description: "" },
  # xbcrafted
  { alias: "xbcrafted", episode: 1, season: 8, youtube_video_id: "k6iJ-eV_xBk",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/k6iJ-eV_xBk/mqdefault.webp",
    description: "" },
  # xisumavoid
  { alias: "xisumavoid", episode: 1, season: 8, youtube_video_id: "DmlEBhvn1Sg",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi_webp/DmlEBhvn1Sg/mqdefault.webp",
    description: "" },
  # zedaphplays
  { alias: "zedaphplays", episode: 1, season: 8, youtube_video_id: "xglsGT1qOXA",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/xglsGT1qOXA/mqdefault.jpg",
    description: "" },
  # zombiecleo
  { alias: "zombiecleo", episode: 1, season: 8, youtube_video_id: "SBgcFf2ooe0",
    title: "Hermit Craft, ep 1", subtitle: "episode 1",
    thumbnail_url: "https://i.ytimg.com/vi/SBgcFf2ooe0/mqdefault.jpg",
    description: "" }
].freeze

# ============================================================================
# SEEDING LOGIC
# ============================================================================

hermit_map = {}

# --- Seed detailed hermits ---
DETAILED_HERMIT_DATA.each do |data|
  hermit = Hermit.find_or_initialize_by(alias: data[:alias])
  hermit.assign_attributes(
    first_name: data[:first_name],
    last_name: data[:last_name],
    nick_name: data[:nick_name],
    alias_image_url: data[:alias_image_url],
    alias_image_alt: data[:alias_image_alt],
    subs: data[:subs],
    quote: data[:quote],
    info2: data[:info2],
    youtube: data[:youtube],
    twitch: data[:twitch],
    twitter: data[:twitter],
    instagram: data[:instagram],
    patreon: data[:patreon],
    skin_url: data[:skin_url],
    skin_alt: data[:skin_alt],
    face_url: data[:face_url],
    face_alt: data[:face_alt],
    avatar_url: data[:avatar_url],
    banner_url: data[:banner_url],
    from: data[:from_place]
  )
  hermit.save!

  # Set rich text content separately
  hermit.info = ActionText::Content.new(data[:info_text]) if data[:info_text].present?

  hermit_map[data[:alias]] = hermit
  puts "  Hermit created/updated: #{hermit.alias} (slug: #{hermit.slug})"
end

# --- Seed minimal hermits ---
MINIMAL_HERMIT_DATA.each do |data|
  hermit = Hermit.find_or_initialize_by(alias: data[:alias])
  hermit.assign_attributes(
    nick_name: data[:nick_name],
    from: data[:from_place]
  )
  hermit.save!

  hermit_map[data[:alias]] = hermit
  puts "  Hermit created/updated: #{hermit.alias} (slug: #{hermit.slug})"
end

# --- Seed crews ---
CREWS.each do |crew_data|
  crew = HermitCrew.find_or_initialize_by(slug: crew_data[:slug])
  crew.assign_attributes(
    name: crew_data[:name],
    description: crew_data[:description],
    image_url: crew_data[:image_url],
    season: crew_data[:season]
  )
  crew.save!

  # Assign members
  crew_data[:member_aliases].each do |member_alias|
    hermit = hermit_map[member_alias]
    if hermit
      HermitCrewMembership.find_or_create_by!(hermit: hermit, hermit_crew: crew)
      puts "    Member #{hermit.alias} -> #{crew.name}"
    else
      puts "    WARNING: Hermit not found for alias '#{member_alias}' in crew '#{crew.name}'"
    end
  end

  puts "  Crew created/updated: #{crew.name}"
end

# --- Seed sample videos ---
SAMPLE_VIDEOS.each do |vid|
  hermit = hermit_map[vid[:alias]]
  unless hermit
    puts "  WARNING: Hermit '#{vid[:alias]}' not found for video #{vid[:youtube_video_id]}"
    next
  end

  video = HermitVideo.find_or_initialize_by(youtube_video_id: vid[:youtube_video_id])
  video.title         = vid[:title]
  video.season        = vid[:season]
  video.episode       = vid[:episode]
  video.thumbnail_url = vid[:thumbnail_url]
  video.hermit        = hermit
  video.save!

  puts "  Video seeded: #{video.title} (#{hermit.alias} Ep.#{video.episode})"
end

puts "--- Hermit Plus Season 8 seeding complete ---"
puts "  Hermits: #{Hermit.count}"
puts "  HermitCrews: #{HermitCrew.count}"
puts "  HermitCrewMemberships: #{HermitCrewMembership.count}"
puts "  HermitVideos: #{HermitVideo.count}"
