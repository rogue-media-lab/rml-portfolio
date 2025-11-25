# Tailwind CSS Fix

This document explains the steps taken to fix the Tailwind CSS setup in this project.

## Problem

The `bin/rails tailwindcss:build` command was failing with the following error:

```
Error: Cannot apply unknown utility class `bg-st-drk-primary`
```

This was happening because the custom colors were not being loaded correctly by Tailwind CSS.

## Solution

The following steps were taken to fix the issue:

1.  **Removed `input.css` and `output.css`:** These files were not being used and were remnants of a previous setup.
2.  **Ensured `tailwindcss-rails` gem is in the `Gemfile`:** The `tailwindcss-rails` gem is the recommended way to integrate Tailwind CSS into Rails 8 applications without Node.js.
3.  **Run the `./bin/rails tailwindcss:install` command:** This command creates the necessary files and directories for the `tailwindcss-rails` gem.
4.  **Moved custom CSS to `app/assets/tailwind/application.css`:** The custom CSS was moved from `app/assets/stylesheets/application.tailwind.css` to the new `app/assets/tailwind/application.css` file.
5.  **Removed `app/assets/stylesheets/application.tailwind.css`:** The old file was removed.
6.  **Configured custom colors in `@theme` block:** The custom colors were correctly configured in the `@theme` block in `app/assets/tailwind/application.css`. The color names were changed to the correct format, e.g., `--color-st-drk-primary`.
7.  **Successfully built the CSS:** The CSS was successfully built using the `bin/rails tailwindcss:build` command.

## Key Takeaways

*   With `tailwindcss-rails` v4, custom colors are defined in `app/assets/tailwind/application.css` using the `@theme` directive.
*   The color names must be in the format `--color-<name>`.
*   The `tailwind.config.js` file is not used for defining custom colors in this setup.
*   The `config/tailwindcss.rb` file can be used to customize the behavior of the `tailwindcss-rails` gem, but it is not necessary for this project.
