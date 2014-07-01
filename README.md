## Examples

ActiveRecord is not required, but let me write an example for it.

```ruby
ActsAsGit.configure do |config|
  config.email = 'test@test.com'
  config.username = 'testuser'
end

class Post < ActiveRecord::Base
  include ActsAsGit
  def self.repodir
    "posts"
  end

  def filename
    "#{self.id}_body.txt"
  end
  acts_as_git :body => self.instance_method(:filename)
end

# store
post = Post.new # create the directory `self.repodir` if not exist, and init repo.
post.body = 'content'
post.save # save the content into the file of `#filename`
post.current
  => COMMIT_HASH_HOGE

# load
post = Post.first
puts post.body
  => 'content'

# history
post.body = 'content2'
post.is_changed?
  => true
post.save
post.is_changed?
  => false
post.current
  => COMMIT_HASH_FUGA
puts post.body
  => 'content2'
post.checkout(COMMIT_HASH_HOGE)
puts post.body
  => 'content'
```
