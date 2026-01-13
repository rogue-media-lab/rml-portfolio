# frozen_string_literal: true

class MilkAdmin::CustomSoundCloudArtworksController < ApplicationController
  include ZukeAuth
  before_action :authenticate_zuke_admin!
  before_action :set_artwork, only: [:customize, :update, :destroy]

  def index
    @artworks = CustomSoundCloudArtwork.order(updated_at: :desc)
                                       .with_attached_custom_image
  end

  # Sync liked songs from SoundCloud API
  def sync
    soundcloud_likes = SoundcloudLikesService.fetch_likes

    synced_count = 0
    soundcloud_likes.each do |like|
      track = like["track"]
      next if track.blank? # Skip if the track object is missing

      # Create or update the record with cached track info
      artwork = CustomSoundCloudArtwork.find_or_initialize_by(
        soundcloud_track_id: track['id'].to_s
      )

      artwork.update(
        track_title: track['title'],
        track_artist: track.dig('user', 'username')
      )

      synced_count += 1 if artwork.persisted?
    end

    redirect_to milk_admin_custom_sound_cloud_artworks_path,
                notice: "Synced #{synced_count} tracks from SoundCloud Likes"
  rescue => e
    redirect_to milk_admin_custom_sound_cloud_artworks_path,
                alert: "Error syncing: #{e.message}"
  end

  def customize
    # Load all existing images from Songs for the carousel
    @existing_images = Song.with_attached_image
                           .where.not(id: nil)
                           .select { |song| song.image.attached? }
  end

  def update
    if params[:use_existing_image_id].present?
      # User selected an existing image from another song
      source_song = Song.find(params[:use_existing_image_id])
      if source_song.image.attached?
        @artwork.custom_image.attach(source_song.image.blob)
      end
    elsif params[:custom_sound_cloud_artwork][:custom_image].present?
      # User uploaded a new image
      @artwork.custom_image.attach(params[:custom_sound_cloud_artwork][:custom_image])
    end

    if @artwork.save
      redirect_to milk_admin_custom_sound_cloud_artworks_path,
                  notice: "Custom artwork saved for #{@artwork.track_title}"
    else
      render :customize
    end
  end

  def destroy
    @artwork.custom_image.purge if @artwork.custom_image.attached?
    @artwork.destroy

    redirect_to milk_admin_custom_sound_cloud_artworks_path,
                notice: "Custom artwork removed"
  end

  private

  def set_artwork
    @artwork = CustomSoundCloudArtwork.find(params[:id])
  end

  def artwork_params
    params.require(:custom_sound_cloud_artwork).permit(:custom_image)
  end
end
