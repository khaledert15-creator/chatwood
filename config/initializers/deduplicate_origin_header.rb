# OpenLiteSpeed's reverse proxy sends the Origin header twice ("https://x, https://x"),
# which fails Rails' CSRF origin check and rejects every Super Admin form with a 422.
class DeduplicateOriginHeader
  def initialize(app)
    @app = app
  end

  def call(env)
    origins = env['HTTP_ORIGIN'].to_s.split(/,\s*/)
    env['HTTP_ORIGIN'] = origins.first if origins.size > 1 && origins.uniq.size == 1
    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before 0, DeduplicateOriginHeader
