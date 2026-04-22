# RockPet - Virtual Pet System for Rocky AI Assistant
#
# Rocky starts as an egg and grows through interaction:
# - Stages: egg -> hatchling -> juvenile -> adult -> elder -> legendary
# - XP earned from sending messages, having conversations
# - Level up triggers stat increases and unlocks new abilities
# - Skills, achievements, and personality evolve over time
#
class RockPet < ApplicationRecord
  belongs_to :user

  # Pet stages in order of growth
  STAGES = %w[egg hatchling juvenile adult elder legendary].freeze

  # Stages where Rocky can be "hatched" from egg
  HATCH_STAGES = %w[hatchling juvenile adult elder legendary].freeze

  # XP multiplier for different interactions
  XP_PER_MESSAGE = 10
  XP_PER_WORD = 1
  XP_BONUS_CONVERSATION_STARTER = 25
  XP_PER_CONVERSATION = 50

  # Stage thresholds (level required)
  STAGE_LEVEL_THRESHOLDS = {
    "egg" => 0,
    "hatchling" => 1,
    "juvenile" => 5,
    "adult" => 15,
    "elder" => 30,
    "legendary" => 50
  }.freeze

  # Skills that can be learned at each stage
  STAGE_SKILLS = {
    "hatchling" => ["basic_chat"],
    "juvenile" => ["tone_matching", "memory"],
    "adult" => ["creativity", "reasoning"],
    "elder" => ["wisdom", "mentor"],
    "legendary" => ["enlightenment"]
  }.freeze

  # Achievement definitions
  ACHIEVEMENTS = {
    first_message: { name: "First Words", description: "Send your first message to Rocky", icon: "👶" },
    ten_messages: { name: "Chatty", description: "Exchange 10 messages", icon: "💬" },
    fifty_messages: { name: "Conversationalist", description: "Exchange 50 messages", icon: "🗣️" },
    hundred_messages: { name: "Best Friends", description: "Exchange 100 messages", icon: "🤝" },
    conversation_starter: { name: "Ice Breaker", description: "Start a new conversation", icon: "🆕" },
    five_conversations: { name: "Regular", description: "Have 5 conversations", icon: "📅" },
    level_5: { name: "Growing Up", description: "Reach level 5", icon: "⭐" },
    level_10: { name: "Teenager", description: "Reach level 10", icon: "🌟" },
    level_25: { name: "Mature", description: "Reach level 25", icon: "🌠" },
    hatched: { name: "Hatched!", description: "Rocky hatched from the egg", icon: "🐣" },
    first_skill: { name: "Learner", description: "Learn your first skill", icon: "📚" },
    all_skills: { name: "Master", description: "Learn all skills", icon: "🎓" },
    thousand_words: { name: "Wordsmith", description: "Exchange 1000 words", icon: "✍️" }
  }.freeze

  validates :stage, inclusion: { in: STAGES }
  validates :level, numericality: { greater_than_or_equal_to: 1 }

  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :by_level, ->(level) { where("level >= ?", level) }

  # Callbacks
  after_create :initialize_pet

  # Initialize a new pet as an egg
  def initialize_pet
    update!(
      level: 1,
      xp: 0,
      xp_to_next_level: 100,
      stage: "egg",
      personality_attributes: default_personality,
      skills_learned: [],
      achievements: [],
      total_messages: 0,
      total_conversations: 0,
      total_words: 0
    )
  end

  # Called when user sends a message - grants XP and updates stats
  def interact!(word_count:, is_new_conversation: false)
    transaction do
      # Calculate XP gain
      xp_gain = XP_PER_MESSAGE + (word_count * XP_PER_WORD)
      xp_gain += XP_BONUS_CONVERSATION_STARTER if is_new_conversation

      # Update stats
      new_total_messages = total_messages + 1
      new_total_words = total_words + word_count
      new_conversations = is_new_conversation ? total_conversations + 1 : total_conversations

      update!(
        total_messages: new_total_messages,
        total_words: new_total_words,
        total_conversations: new_conversations,
        last_interaction_at: Time.current
      )

      # Add XP and check for level up
      add_xp!(xp_gain)

      # Check for stage transition
      check_stage_transition!

      # Check for new achievements
      check_achievements!
    end

    self
  end

  # Add XP and handle level ups
  def add_xp!(amount)
    new_xp = xp + amount
    new_level = level
    new_xp_to_next = xp_to_next_level

    # Handle multiple level ups at once
    while new_xp >= new_xp_to_next && new_level < 100
      new_xp -= new_xp_to_next
      new_level += 1
      new_xp_to_next = calculate_xp_for_level(new_level)

      # Learn new skills on level up
      learn_skills_for_level(new_level)
    end

    update!(xp: new_xp, level: new_level, xp_to_next_level: new_xp_to_next)
  end

  # Calculate XP needed for a given level (scales with level)
  def calculate_xp_for_level(level)
    # XP curve: 100, 150, 225, 337, 506... (exponential growth)
    (100 * (1.5 ** (level - 1))).to_i
  end

  # Check if pet should transition to next stage
  def check_stage_transition!
    current_stage_index = STAGES.index(stage)
    return if current_stage_index.nil? || current_stage_index >= STAGES.size - 1

    next_stage = STAGES[current_stage_index + 1]
    threshold = STAGE_LEVEL_THRESHOLDS[next_stage]

    if level >= threshold && stage != next_stage
      update!(stage: next_stage)
      on_stage_change!
    end
  end

  # Hook for special behavior on stage change
  def on_stage_change!
    # Add hatch achievement when egg hatches
    if stage == "hatchling" && !achievements.include?("hatched")
      add_achievement!("hatched")
    end
  end

  # Learn new skills based on level/stage
  def learn_skills_for_level(new_level)
    new_skills = STAGE_SKILLS.values.flatten.select do |_skill, levels|
      levels.include?(new_level)
    end

    new_skills.each do |skill|
      add_skill!(skill) unless skills_learned.include?(skill)
    end
  end

  # Add a skill to the pet
  def add_skill!(skill)
    return if skills_learned.include?(skill)

    new_skills = skills_learned + [skill]
    update!(skills_learned: new_skills)

    # Check for first skill achievement
    add_achievement!("first_skill") if new_skills.size == 1

    # Check for all skills achievement
    all_possible_skills = STAGE_SKILLS.values.flatten.map(&:first)
    add_achievement!("all_skills") if (all_possible_skills - new_skills).empty?
  end

  # Add an achievement
  def add_achievement!(achievement_key)
    return unless ACHIEVEMENTS.key?(achievement_key)
    return if achievements.include?(achievement_key.to_s)

    new_achievements = achievements + [achievement_key.to_s]
    update!(achievements: new_achievements)
  end

  # Check all achievements and unlock any that are earned
  def check_achievements!
    add_achievement!("first_message") if total_messages >= 1
    add_achievement!("ten_messages") if total_messages >= 10
    add_achievement!("fifty_messages") if total_messages >= 50
    add_achievement!("hundred_messages") if total_messages >= 100
    add_achievement!("five_conversations") if total_conversations >= 5
    add_achievement!("thousand_words") if total_words >= 1000
    add_achievement!("level_5") if level >= 5
    add_achievement!("level_10") if level >= 10
    add_achievement!("level_25") if level >= 25
  end

  # Get stage emoji for display
  def stage_emoji
    {
      "egg" => "🥚",
      "hatchling" => "🐣",
      "juvenile" => "🦎",
      "adult" => "🐉",
      "elder" => "🐲",
      "legendary" => "✨"
    }[stage] || "🥚"
  end

  # Get progress to next level as percentage
  def level_progress
    return 0 if xp_to_next_level.zero?
    ((xp.to_f / xp_to_next_level) * 100).round(1)
  end

  # Get progress to next stage as percentage
  def stage_progress
    current_stage_index = STAGES.index(stage)
    return 100 if current_stage_index.nil? || current_stage_index >= STAGES.size - 1

    next_stage = STAGES[current_stage_index + 1]
    threshold = STAGE_LEVEL_THRESHOLDS[next_stage]
    current_threshold = STAGE_LEVEL_THRESHOLDS[stage]

    return 100 if threshold.nil? || threshold == current_threshold

    progress = ((level - current_threshold).to_f / (threshold - current_threshold) * 100).clamp(0, 100)
    progress.round(1)
  end

  # Get next stage name
  def next_stage
    current_stage_index = STAGES.index(stage)
    return nil if current_stage_index.nil? || current_stage_index >= STAGES.size - 1

    STAGES[current_stage_index + 1]
  end

  # Get next stage level requirement
  def next_stage_level
    return nil if next_stage.nil?
    STAGE_LEVEL_THRESHOLDS[next_stage]
  end

  # Get achievement details with metadata
  def achievement_details
    achievements.map do |key|
      achievement = ACHIEVEMENTS[key.to_sym]
      next nil if achievement.nil?

      { key: key, name: achievement[:name], description: achievement[:description], icon: achievement[:icon] }
    end.compact
  end

  # Get skill details
  def skill_details
    skills_learned.map do |skill|
      { name: skill, description: skill_description(skill) }
    end
  end

  # Human-readable skill descriptions
  def skill_description(skill)
    {
      "basic_chat" => "Basic conversation abilities",
      "tone_matching" => "Can match and respond to tones",
      "memory" => "Remembers conversation context",
      "creativity" => "Enhanced creative responses",
      "reasoning" => "Improved logical reasoning",
      "wisdom" => "Shares deeper insights",
      "mentor" => "Can guide and teach",
      "enlightenment" => "Ultimate understanding"
    }[skill] || skill.titleize
  end

  # Check if egg can be hatched (requires user interaction)
  def can_hatch?
    stage == "egg" && total_messages >= 5
  end

  # Hatch the egg manually
  def hatch!
    return false unless can_hatch?

    update!(stage: "hatchling")
    add_achievement!("hatched")
    true
  end

  # Update personality based on interaction patterns
  def update_personality!(trait, value)
    current = personality_attributes.dup
    current[trait] = value
    update!(personality_attributes: current)
  end

  # Default personality for new pets
  def default_personality
    {
      curiosity: 50,
      warmth: 50,
      humor: 50,
      patience: 50,
      creativity: 30
    }
  end

  # Get growth summary for UI
  def growth_summary
    {
      level: level,
      stage: stage,
      stage_emoji: stage_emoji,
      xp: xp,
      xp_to_next_level: xp_to_next_level,
      level_progress: level_progress,
      stage_progress: stage_progress,
      next_stage: next_stage,
      next_stage_level: next_stage_level,
      total_messages: total_messages,
      total_conversations: total_conversations,
      total_words: total_words,
      skills_count: skills_learned.size,
      achievements_count: achievements.size,
      can_hatch: can_hatch?,
      nickname: nickname
    }
  end
end