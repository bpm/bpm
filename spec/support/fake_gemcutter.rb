class FakeGemcutter
  def initialize(api_key)
    @api_key = api_key
  end

  def respond(code, text)
    [code, {"Content-Type" => "text/plain"}, text]
  end

  def call(env)
    request = Rack::Request.new(env)

    if request.env["HTTP_AUTHORIZATION"] != @api_key
      respond 401, "One cannot simply walk into Mordor!"
    elsif request.path == "/api/v1/gems" && request.post?
      respond 200, "Successfully registered rake (0.8.7)"
    elsif request.path == "/api/v1/gems/yank" && request.delete?
      version = request.params["version"].to_i
      if version < 1
        respond 404, "This gem could not be found"
      elsif version < 2
        respond 200, "Successfully yanked gem: #{request.params["gem_name"]} (#{request.params["version"]})"
      else
        respond 500, "The version #{request.params["version"]} has already been yanked."
      end
    elsif request.path == "/api/v1/gems/unyank" && request.put?
      version = request.params["version"].to_i
      if version < 1
        respond 404, "This gem could not be found"
      elsif version < 2
        respond 200, "Successfully unyanked gem: #{request.params["gem_name"]} (#{request.params["version"]})"
      else
        respond 500, "The version #{request.params["version"]} is already indexed."
      end
    elsif request.path == "/api/v1/gems/rake/owners"
      if request.post?
        respond 200, "Owner added successfully."
      elsif request.delete?
        respond 200, "Owner removed successfully."
      end
    elsif request.path == "/api/v1/gems/rake/owners.yaml" && request.get?
      yaml = YAML.dump([{'email' => 'geddy@example.com'},
                        {'email' => 'lerxst@example.com'}])
      respond(200, yaml)
    else
      respond(404, "Invalid request")
    end
  end
end

