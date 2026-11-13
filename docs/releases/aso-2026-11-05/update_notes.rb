require 'spaceship'
require 'dotenv'
require 'json'
$stdout.sync = true
Dotenv.load(File.expand_path('../../../.env', __dir__))
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'), issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'), key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT'))
app = Spaceship::ConnectAPI::App.find('com.entaku.VoiceYourText')
version = app.get_app_store_versions.find { |v| v.version_string == '1.4.12' }
raise 'Unexpected state' unless version.app_store_state == 'PREPARE_FOR_SUBMISSION'
notes = JSON.parse(File.read(File.join(__dir__, 'release_notes.json')))
localizations = version.get_app_store_version_localizations
raise 'Locale count mismatch' unless localizations.map(&:locale).sort == notes.keys.sort
localizations.each do |l|
  l.update(attributes: {whats_new: notes.fetch(l.locale)}) unless l.whats_new == notes.fetch(l.locale)
  puts "Updated #{l.locale}"
end
version.get_app_store_version_localizations.each { |l| raise "Mismatch: #{l.locale}" unless l.whats_new == notes.fetch(l.locale) }
puts 'Verified release notes for all 50 locales.'
