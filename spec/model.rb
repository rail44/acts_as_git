require 'acts_as_git'

ActsAsGit.configure do |config|
  config.email = 'test@test.com'
  config.username = 'testuser'
end

class TestPost
  include ActsAsGit
  def self.repodir
    @@repodir = Dir.tmpdir
  end

  def filename
    @filename = 'test_acts_as_git'
  end
  acts_as_git :body => self.instance_method(:filename)
end
