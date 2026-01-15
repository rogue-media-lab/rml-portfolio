class InfoController < ApplicationController
  def index
    # Renders the main page with the initial content
  end

  def welcome
    # Renders app/views/info/welcome.html.erb
  end

  def vibe
    # Renders app/views/info/about_me.html.erb
  end

  def skills
    @pills = Pill.all.group_by(&:group)
    @plain_pills = Pill.all
    # Renders app/views/info/skills.html.erb
  end

  def erudition
    # Render app/views/info/erudition.html.erb
  end
end
