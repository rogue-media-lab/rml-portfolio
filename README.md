![Rails](https://img.shields.io/badge/rails-8.0.2-orange?logo=rubyonrails)
![Ruby](https://img.shields.io/badge/ruby-3.3.7-red?logo=ruby)
![PG](https://img.shields.io/badge/data-PostgreSQL-red?logo=postgresql&logoColor=white)
![Authentication](https://img.shields.io/badge/auth-devise-purple?logo=rubygems&logoColor=white)
![Status](https://img.shields.io/badge/LAB-working-green?logo=jekyll)
![License](https://img.shields.io/badge/license-MIT-green)
![Powered By](https://img.shields.io/badge/powered%20by-COFFEE-brown?logo=coffeescript)

# Rogue Media Lab

*Formerly MILK-00*

![Home screen for Rogue Media Lab](public/Screenshot%20from%202025-11-09%2008-59-33.png)

With the new studio up, it is time to work on the portfolio. Formerly MILK-00, this project holds a lot of promise and already has a lot of functionality. I liked the design and how it works. I love the concept of feeling like you stepped into a different site for the various featured projects. These are working concepts in various stages of development, but those shinny parts are shown here, as you may see them if you visited the app. I love this concept. I can save money by working them into the same platform but you still feel like you are visiting a new place. Hosting each of these would be a strain on my tiny budget.

You need to know that I have taken liberties with various rights to bring these concepts to you. I hope I have done them justice. I love them all so much and wish no harm to any of them. I simply want to show everyone what I can do, and them, that there could be a different way. With Slat and Tar I have ensured you can get to their original content and provided those various social links that they manage. I feel this is an improvement as you can get to all of them from one spot. With the music, and images for the music, I have either changed the sound, adding scratches and pops for that older feel, or modified images with AI in some way. Most of the time making live images. None of that is enough and I should provide a reference to the artist. I apologize if I offend anyone. Early in the build I was focused on making it work. I have grown.

The initial view utilizes Turbo Frames. Clicking a link on the right sidebar will populate the frame on the left. These frames will give information, provide external links, and provides a form for sending internal messages. These frame views are labeled info.

## Feature Projects
There are many projects I love and keep coming back to. With Rails I have been able to get them pulled together into one place to enjoy. Here is some information on each.

### Salt and Tar

![Root for Salt and Tar](public/Screenshot%20from%202025-01-29%2021-07-08.png)

This is a YouTube channel for sailing. Ruth and Garret have built Rediviva and the channel starts from the very beginning. Like many content creators, they juggle several accounts on various platforms. I thought they could use a site / app that gave them features they would use and enjoy while reducing the account overhead. For me, I want to enjoy there videos without the distractions of YouTube. I want the design to be a little different. I want the videos to have a old feel for the build and I want them to be framed like a polaroid picture. I would love to be able to book a overnight berthing or a day sail with them. I would love to bid on things when they are replaced on Rediviva. I would love to purchase merch or support them directly. All of this I will build into the remake. It is built with Rails, styled with Tailwind, larger files are stored in S3, and PostgeSQL is the database. This is a concept, of course. I hope everyone enjoys, and all the information is provided so you can easily support them. If I am honest, having just that home page that includes all those support links in one place, is an improvement.

![Archive for Salt and Tar](public/Screenshot%20from%202025-06-12%2017-17-07.png)

Here is the Archive that includes the first re-worked videos from the building of Rediviva in Washington state. They have a old feel with grain and static lines. The original video is linked with the youtube icon below the main video in the polaroid frame.

### Hermit Plus

![Root for Hermit Plus](public/Screenshot%20from%202025-01-29%2021-10-47.png)

Minecraft is a thing. The Hermits have really made it a thing to enjoy. This group of talented players have figured it out. I wanted a different way to enjoy them. Wanted them pulled together into one location. Like Netflix, but with only the Hermits. One YouTube they are spread out in all the noise. Then there is the fan art, the merch, the music for some. They deserve something more.

### Copywriter

![Root for Copywriter](public/Screenshot%20from%202025-01-29%2021-11-35.png)

This project and Barbershop were old Wordpress projects that I just loved the design. Several months back I started the clean up of my LinkedIn and decided to remake this one as all the others were lost. It then moved to here as I wrapped everything together. I did a little research and found a copywriter and decided to rebuild their site with my design. This is a concept but they are real. Wether you love or hate my work, I encourage you to give them a look.

### Blog

![Root for blog](public/Screenshot%20from%202025-01-29%2021-12-31.png)

I have recently started a SubStack account. I finally have this blog up and running. This is intended to help me and others, learn these concepts as I continue this journey. They will provide a glimpse of both my sense of humor and knowledge of design and development.


This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version
  3.3.0

* System dependencies
  Tailwind, PostgreSQL, Ruby, 3.3.0, Rails 8, Devise, aws-s3, active storage and active text.

* Configuration
  Standard Rails configuration with Tailwind and PostgreSql

* Database creation
  Database.yml includes host, default username and password for PostgreSQL. My system does not include root access role under my name. These added config settings allow for quick and easy set up.

* Database initialization
  db:create, db:migrate, db:seed
  Seed file includes generic admin create and some dummy projects, skill pills and such.

* How to run the test suite
  Standard Rails system tests. Very few tests currently. 

* Deployment instructions
  Procfile, package.json set for Heroku deployment. Updated per dependabot requests.

* Environment Variables
  `YOUTUBE_API_KEY` — Required for Hermit Plus YouTube Data API v3 integration.
  Set in `.env` locally or Heroku config vars for production.
  Get a key at https://console.cloud.google.com/apis/credentials
  Quota: 10,000 units/day (free tier)

* ...


