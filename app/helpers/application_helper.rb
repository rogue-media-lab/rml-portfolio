module ApplicationHelper
  # ── Salt & Tar helpers ──────────────────────────────────

  def responsive_width_class
    "flex w-full px-6 lg:px-0 lg:w-[950px] xl:w-[1024px]"
  end

  def menu_link(text, path, options = {})
    base_classes = "flex p-2 my-1 hover:bg-gray-50 rounded-sm"
    classes = "#{base_classes} #{options[:class]}"
    link_to text, path, class: classes
  end

  # ── Meta tags ───────────────────────────────────────────
  def default_meta_tags
    {
      site: "Rogue Media Lab",
      title: "Rogue Media Lab",
      reverse: true,
      separator: "|",
      description: "Full-stack development, design, and creative content by Mason Roberts",
      keywords: "web development, rails, ruby, design, full stack, blog",
      og: {
        site_name: "Rogue Media Lab",
        type: "website"
      },
      twitter: {
        card: "summary_large_image"
      }
    }
  end

  # A helper to ensure a URL is safe to link to
  def safe_link_url(url)
    return nil if url.blank?

    allowed_protocols = [ "http", "https" ]

    begin
      uri = URI.parse(url)
      # Check if the URL's protocol is in our allow-list (http, https)
      if uri.scheme.present? && allowed_protocols.include?(uri.scheme.downcase)
        return url
      end
    rescue URI::InvalidURIError
      # If the URL is badly formed (e.g., "http://["), don't link to it
      return nil
    end

    # If it has no protocol (e.g., "google.com") or an unsafe one (e.g., "javascript:alert(1)"),
    # prepend 'http://' to safely treat it as an external link.
    # "http://google.com" works. "http://javascript:alert(1)" is harmless.
    "http://#{url}"
  end

  def project_link(url, text)
    # Don't render anything if the URL is blank
    return if url.blank?

    # Use our *other* helper to build the safe URL
    safe_url = safe_link_url(url)

    # Define the common classes
    link_classes = "text-white text-sm font-semibold font-['Albert Sans'] my-2"

    link_to text, safe_url, class: link_classes, target: "_blank", rel: "noopener noreferrer"
  end
end
