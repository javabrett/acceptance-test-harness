#!/usr/bin/env ruby
# vim: tabstop=2 expandtab shiftwidth=2

$LOAD_PATH.push File.dirname(__FILE__) + "/../.."
Dir.glob(File.dirname(__FILE__) + "/../../lib/controller/*.rb") do |name|
  require name
end

Before('@realupdatecenter') do |scenario|
  @controller_options = {:real_update_center => true}
end

Before do |scenario|
  # in case we are using Sauce, set the test name
  Sauce.config do |c|
    c[:name] = Sauce::Capybara::Cucumber.name_from_scenario(scenario)
  end

  # default is to run locally, but allow the parameters to be given as env vars
  # so that rake can be invoked like "rake test type=remote_sysv"
  if ENV['type']
    controller_args = {}
    ENV.each { |k,v| controller_args[k.to_sym]=v }
  else
    controller_args = { :type => :local }
  end

  if @controller_options
    controller_args = controller_args.merge(@controller_options)
  end
  @runner = JenkinsController.create(controller_args)
  @runner.start
  at_exit do
    @runner.stop
    @runner.teardown
  end
  @base_url = @runner.url
  Capybara.app_host = @base_url

  # wait for Jenkins to properly boot up and finish initialization
  s = Capybara.current_session
  for i in 1..20 do
    begin
      s.visit "/systemInfo"
      s.find "TABLE.bigtable"
      break # found it
    rescue => e
      sleep 0.5
    end
  end
end

# Skip scenarios that are not applicable for given Jenkins version
Before do |scenario|

  version = @runner.jenkins_version

  should_run = scenario.feature.applicable_for?(version) && scenario.applicable_for?(version)

  if !should_run
    scenario.skip_invoke!
  end
end

After do |scenario|
  @runner.stop # if test fails, stop in at_exit is not called
  @runner.teardown
end
