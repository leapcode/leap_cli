source 'https://rubygems.org'
gemspec

# #
# # Specify support gems used that we might also develop locally.
# #
# # Available options:
# #
# # :dev_path - the development path of the gem. this path is used if running in 'development mode'.
# #
# # :vendor_path - where this gem is vendored. this path is used if it exists and we are running in 'production mode'
# #
# development_gems = {
#   'supply_drop' => {:dev_path => '../gems/supply_drop', :vendor_path => 'vendor/supply_drop'},
#   'certificate_authority' => {:dev_path => '../gems/certificate_authority', :vendor_path => 'vendor/certificate_authority'}
# }

# #
# # A little bit of code to magically pick the correct gem
# #

# mode = :production

# gem_root = File.dirname(__FILE__)
# path_key = mode == :development ? :dev_path : :vendor_path
# development_gems.each do |gem_name, options|
#   path = File.expand_path(options[path_key], gem_root)
#   if File.directory?(path)
#     gem gem_name, :path => path
#   else
#     gem gem_name
#   end
# end
