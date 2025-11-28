module SidebarHelper
  SIDEBAR_CONTROLLER = "music--sidebar".freeze

  def sidebar_link_to(name, path, icon_name, options = {})
    content_tag :li, class: "gap-3 px-4 py-3 hover:bg-gray-800 transition-colors",
                     data: { "#{SIDEBAR_CONTROLLER}-target": "link",
                     action: "click->#{SIDEBAR_CONTROLLER}#setActive" } do
      link_to path, class: "flex items-center text-gray-300 hover:text-white cursor-pointer", data: options[:data] || {} do
        concat icon(icon_name)
        concat content_tag(:span, name, class: "ms-3")
      end
    end
  end

  def icon(name)
    # Render SVG icons in icons folder, based on the name
    render "icons/#{name}"
  end

  # info links used in the main root
  def info_nav_link(name, path, options = {})
    # Default classes for the navigation links
    default_classes = "border dark:border-milk-light border-base-dark rounded-md p-2 w-full mb-4"

    # Merge default classes with any provided classes
    options[:class] = [ default_classes, options[:class] ].compact.join(" ")

    # Create the link
    link_to name, path, options
  end
end
