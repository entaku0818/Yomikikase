require 'spaceship'
require 'dotenv'
require 'json'
root = File.expand_path('../../..', __dir__)
Dotenv.load(File.join(root, '.env'))
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'), issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'), key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT'))
app = Spaceship::ConnectAPI::App.find('com.entaku.VoiceYourText')
version = app.get_app_store_versions.find { |v| v.version_string == '1.4.12' }
raise 'Unexpected draft state' unless version && version.app_store_state == 'PREPARE_FOR_SUBMISSION'
info = app.fetch_edit_app_info
raise 'No editable app info' unless info
versions = version.get_app_store_version_localizations
infos = info.get_app_info_localizations
changes = JSON.parse(File.read(File.join(__dir__, 'metadata.json')))
backup = changes.keys.to_h do |locale|
  v = versions.find { |x| x.locale == locale }; i = infos.find { |x| x.locale == locale }
  raise "Missing #{locale}" unless v && i
  [locale, {description: v.description, keywords: v.keywords, whats_new: v.whats_new, subtitle: i.subtitle}]
end
path = File.join(__dir__, 'before.json')
File.write(path, JSON.pretty_generate(backup)) unless File.exist?(path)
changes.each do |locale, fields|
  versions.find { |x| x.locale == locale }.update(attributes: fields.slice('description', 'keywords', 'whats_new'))
  infos.find { |x| x.locale == locale }.update(attributes: fields.slice('subtitle'))
end
versions = version.get_app_store_version_localizations
infos = info.get_app_info_localizations
changes.each do |locale, fields|
  v = versions.find { |x| x.locale == locale }; i = infos.find { |x| x.locale == locale }
  %w[description keywords whats_new].each { |key| raise "Mismatch #{locale}/#{key}" unless v.public_send(key) == fields[key] }
  raise "Mismatch #{locale}/subtitle" unless i.subtitle == fields['subtitle']
  puts "Verified #{locale}: description, keywords, release notes, subtitle"
end
puts '1.4.12 metadata updated; not submitted.'
