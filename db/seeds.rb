# Load restaurant seeds
require_relative "seeds/restaurants"

puts "Deleting all videos..."
SaltAndTarVideo.destroy_all

videos = [
  {
    title: "Salt&Tar - Part 1",
    description: "First steps in constructing the wooden sailboat.",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep1a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep1a.jpg",
    youtube_url: "https://youtu.be/gkTKQKdfz9k?si=oVF3nWA14HVnhHrl",
    position: 1,
    published: true
  },
  {
    title: "Salt&Tar - Part 2",
    description: "Ballast pour!",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep2a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep2a.jpg",
    youtube_url: "https://youtu.be/8oqttpxm1uM?si=6wClS1BD-FXBvHJK",
    position: 2,
    published: true
  },
  {
    title: "Salt&Tar - Part 3",
    description: "Details of the framing process...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep3a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep3a.jpg",
    youtube_url: "https://youtu.be/H61LoOjj9KU?si=0oOakcdSwuSOG-t0",
    position: 3,
    published: true
  },
  {
    title: "Salt&Tar - Part 4",
    description: "Continue the framing process...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep4a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep4a.jpg",
    youtube_url: "https://youtu.be/p8Xl8xiPzBY?si=1GcYuSWZBH_90Pqx",
    position: 4,
    published: true
  },
  {
    title: "Salt&Tar - Part 5",
    description: "A day in the life of the boat...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep5a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep5a.jpg",
    youtube_url: "https://youtu.be/Do-xS4HNrLw?si=xj6HJ-MxIdSHpDeE",
    position: 5,
    published: true
  },
  {
    title: "Salt&Tar - Part 6",
    description: "Still cold in Washington state...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep6a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep6a.jpg",
    youtube_url: "https://youtu.be/tBdoy6MQ3OM?si=T55T9QRwhR2-3oq1",
    position: 6,
    published: true
  },
  {
    title: "Salt&Tar - Part 7",
    description: "Milling some wood...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep7a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep7a.jpg",
    youtube_url: "https://youtu.be/3niWN-E-WBw?si=lD62Gxw9vRj2v3F-",
    position: 7,
    published: true
  },
  {
    title: "Salt&Tar - Part 8",
    description: "Planking begins...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep8a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep8a.jpg",
    youtube_url: "https://youtu.be/Gsl8RPMGbuk?si=ZqNP5D2DaZYkG32M",
    position: 8,
    published: true
  },
  {
    title: "Salt&Tar - Part 9",
    description: "Engine...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep9a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep9a.jpg",
    youtube_url: "https://youtu.be/amg2r2RfCf0?si=r56wSsCKBZJlTf0E",
    position: 9,
    published: true
  },
  {
    title: "Salt&Tar - Part 10",
    description: "Working through the trials...",
    video_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep10a.mp4",
    thumbnail_url: "https://milk-blog.s3.us-east-2.amazonaws.com/saltandtar/videos/st-ep10a.jpg",
    youtube_url: "https://youtu.be/cmafWN5IAn4?si=nK2jHwwlQNluA2nJ",
    position: 10,
    published: true
  }
  # Add more videos...
]

# Insert into database
SaltAndTarVideo.create!(videos)
