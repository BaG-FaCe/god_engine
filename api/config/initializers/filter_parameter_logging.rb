# Never log credentials, tokens or provider API keys.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn
  api_key apiKey api_key_encrypted authorization bearer
  password password_confirmation client_secret
]
