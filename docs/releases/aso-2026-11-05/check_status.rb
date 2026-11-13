require 'spaceship'
require 'dotenv'
require 'json'
Dotenv.load(File.expand_path('../../../.env', __dir__))
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'), issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'), key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT'))
app = Spaceship::ConnectAPI::App.find('com.entaku.VoiceYourText')
v = app.get_app_store_versions.find { |x| x.version_string == '1.4.12' }
builds = Spaceship::ConnectAPI::Build.all(app_id: app.id, version: '1.4.12', build_number: '48')
puts JSON.pretty_generate({version: v.version_string, state: v.app_store_state, release_type: v.release_type, builds: builds.map { |b| {id: b.id, build: b.version, state: b.processing_state} }})
puts JSON.pretty_generate({uploads: Spaceship::ConnectAPI::BuildUpload.all(app_id: app.id, version: '1.4.12', build_number: '48').map { |b| {id: b.id, state: b.state, uploaded: b.uploaded_date} }})
