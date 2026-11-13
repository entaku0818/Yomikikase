require 'spaceship'
require 'dotenv'
require 'json'
$stdout.sync = true
Dotenv.load(File.expand_path('../../../.env', __dir__))
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'), issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'), key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT'))
app = Spaceship::ConnectAPI::App.find('com.entaku.VoiceYourText')
version = app.get_app_store_versions.find { |v| v.version_string == '1.4.12' }
raise 'Unexpected state' unless version.app_store_state == 'PREPARE_FOR_SUBMISSION'
build = Spaceship::ConnectAPI::Build.all(app_id: app.id, version: '1.4.12', build_number: '48').find { |b| b.processing_state == 'VALID' }
raise 'Build 48 is not VALID' unless build
notes = JSON.parse(File.read(File.join(__dir__, 'release_notes.json')))
version.get_app_store_version_localizations.each { |l| raise "Release notes mismatch: #{l.locale}" unless l.whats_new == notes.fetch(l.locale) }
version.select_build(build_id: build.id)
# Submit for review with manual release; automatic publication was rejected by approval review.
version.update(attributes: {release_type: 'MANUAL'})
submission = app.get_ready_review_submission(platform: 'IOS') || app.create_review_submission(platform: 'IOS')
items = Spaceship::ConnectAPI::ReviewSubmissionItem.all(review_submission_id: submission.id, includes: 'appStoreVersion')
raise 'Submission contains another item' unless items.all? { |i| i.app_store_version&.id == version.id }
submission.add_app_store_version_to_review_items(app_store_version_id: version.id) if items.empty?
result = submission.submit_for_review
record = {version: '1.4.12', build: '48', version_id: version.id, build_id: build.id, submission_id: submission.id, state: result.state, release_type: 'MANUAL', submitted_at: Time.now.utc.to_s}
File.write(File.join(__dir__, 'submission.json'), JSON.pretty_generate(record))
puts JSON.pretty_generate(record)
