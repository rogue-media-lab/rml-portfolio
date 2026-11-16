# frozen_string_literal: true

require "test_helper"

# The full track must never reach a public surface.
#
# The plan called for this as a grep rather than a method, and the reason is the
# one that matters: a test which only covers the files you remembered to change
# is worth nothing. Four views were fixed for this bug and a fifth was missed;
# a test asserting behaviour on the pages I happened to think of would have
# missed it too.
#
# So this reads the public Zuke code as source and fails if `audio_file` appears
# outside a comment. Comments are stripped first — prose about the boundary is
# fine, and the previous bugs are documented in exactly those comments.
class ZukePublicBoundaryTest < ActiveSupport::TestCase
  # Every file that can put text in front of a signed-out visitor.
  #
  # app/views/playlists and PlaylistsController were missing from this list when
  # it was first written, and a guard assembled from the files that come to mind
  # is exactly the guard that misses one — the failure this test exists to
  # prevent. They render into Zuke's public "music-frame" for signed-out
  # visitors, so they belong here.
  PUBLIC_SURFACE = %w[
    app/views/zuke
    app/views/playlists
    app/presenters/song_presenter.rb
    app/controllers/zuke_controller.rb
    app/controllers/playlists_controller.rb
    app/helpers
  ].freeze

  # Admin, upload and job surfaces legitimately handle the master.
  test "no public Zuke surface serves or names the full track" do
    offenders = public_surface_files.filter_map do |path|
      code = strip_comments(File.read(path))
      hits = code.lines.each_with_index.filter_map do |line, i|
        "#{path}:#{i + 1}: #{line.strip}" if line.include?("audio_file")
      end
      hits if hits.any?
    end.flatten

    assert_empty offenders, <<~MESSAGE
      The full track appears in code on a public surface. The public player serves
      the PREVIEW; a full-track URL reaching a signed-out visitor is the exact
      regression this guards.

      #{offenders.join("\n")}
    MESSAGE
  end

  # The guard is only worth having if it can fail. This asserts the comment
  # stripping did not quietly loosen it into a no-op.
  test "the boundary guard still recognises a real leak" do
    sample = <<~ERB
      <%# song.audio_file is mentioned in a comment, which is allowed %>
      <%= song.audio_file.url %>
    ERB

    assert_includes strip_comments(sample), "audio_file",
      "the guard strips too much and would miss a real leak"
  end

  test "the guard ignores a leak that only exists in a comment" do
    sample = <<~ERB
      <%# this used to interpolate song.audio_file and broke every play button %>
      <%= song.preview_audio.url %>
    ERB

    assert_not_includes strip_comments(sample), "audio_file",
      "documenting the boundary must not fail the guard that enforces it"
  end

  private

  def public_surface_files
    PUBLIC_SURFACE.flat_map do |entry|
      path = Rails.root.join(entry)
      path.directory? ? Dir.glob(path.join("**/*.{erb,rb}")) : path.to_s
    end
  end

  # Removes ERB comment blocks, HTML comments, and whole-line Ruby comments.
  # Deliberately does NOT strip trailing `#` comments — a `#` inside a string
  # literal would be mangled, and a leak on a code line would then be hidden.
  def strip_comments(source)
    source
      .gsub(/<%#.*?%>/m, "")
      .gsub(/<!--.*?-->/m, "")
      .gsub(/^\s*#.*$/, "")
      .gsub(/^\s*<%#/, "")
  end
end
