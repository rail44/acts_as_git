require 'fileutils'
require 'rugged'

module ActsAsGit
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  def self.configure
    ClassMethods.module_eval do
      yield self
    end
  end

  # ToDo: rename if filename is changed
  module ClassMethods
    def self.email=(email)
      @@email = email
    end

    def self.username=(username)
      @@username = username
    end

    @@remote = nil
    def self.remote=(remote)
      @@remote = remote
    end

    def get_option(index)
      option = {}
      option[:author] = { :email => @@email, :name => @@username, :time => Time.now }
      option[:committer] = { :email => @@email, :name => @@username, :time => Time.now }
      option[:parents] = @@repo.empty? ? [] : [ @@repo.head.target ].compact
      option[:tree] = index.write_tree(@@repo)
      option[:update_ref] = 'HEAD'
      option
    end

    # acts_as_git :field => self.instance_method(:filename)
    def acts_as_git(params = {})
      self.class_eval do
        unless method_defined?(:save_with_file)
          repodir = self.repodir
          FileUtils.mkdir_p(repodir)
          begin
            @@repo = Rugged::Repository.new(repodir)
          rescue
            Rugged::Repository.init_at(repodir)
            @@repo = Rugged::Repository.new(repodir)
          end
          @@origin = @@repo.remotes['origin'] || @@repo.remotes.create('origin', @@remote) if @@remote

          def current
            if @current
              @current
            else
             (@@repo.empty?)? nil: @@repo.head.target
            end
          end

          def is_changed?
            (@is_changed)? true: false
          end

          define_method :path do |field|
            filename = params[field].bind(self).call
            File.join(self.class.repodir, filename)
          end

          define_method :log do |field|
            filename = params[field].bind(self).call
            walker = Rugged::Walker.new(@@repo)
            walker.sorting(Rugged::SORT_DATE)
            walker.push(@@repo.head.target)
            commits = []
            walker.map do |commit|
              if commit.diff(paths: [path(field)])
                commit
              end
            end
          end

          define_method :checkout do |commit|
            @current = case commit
            when Rugged::Commit
              commit
            when String
              @current = (commit)? @@repo.lookup(commit): nil
            end
            @is_changed = false
            params.each do |field, filename_instance_method|
              field = nil
            end
            self
          end

          def self.sync
            cred = Rugged::Credentials::SshKeyFromAgent.new(username: 'git')
            @@origin.fetch(credentials: cred)
            @@repo.checkout('origin/master', :strategy => :force)
            branch = @@repo.branches["master"]
            @@repo.branches.delete(branch) if branch
            @@repo.create_branch('master')
            @@repo.checkout('master', :strategy => :force)
          end

          define_method(:save_with_file) do |*args|
            params.each do |field, filename_instance_method|
              field_name = :"@#{field}"
              repodir = self.class.repodir
              filename = filename_instance_method.bind(self).call
              content  = instance_variable_get(field_name)
              if repodir and filename and content
                oid = @@repo.write(content, :blob)
                index = @@repo.index
                path = path(field)
                action = File.exists?(path)? 'Update': 'Create'
                FileUtils.mkdir_p(File.dirname(path))
                index.add(path: filename, oid: oid, mode: 0100644)
                option = self.class.get_option(index)
                option[:message] = "#{action} #{filename} for field #{field_name} of #{self.class.name}"
                Rugged::Commit.create(@@repo, option)
                @current = @@repo.head.target
                @@repo.checkout('HEAD', :strategy => :force)
                @is_changed = false
                instance_variable_set(field_name, nil)
              end
            end
            save_without_file(*args)
          end

          define_method(:save) {|*args| } unless method_defined?(:save)
          alias_method :save_without_file, :save
          alias_method :save, :save_with_file

          params.each do |field, filename_instance_method|
            field_name = :"@#{field}"
            define_method("#{field}=") do |content|
              instance_variable_set(field_name, content)
              @is_changed = true
            end
          end

          params.each do |field, filename_instance_method|
            field_name = :"@#{field}"
            define_method(field) do |offset = nil, length = nil|
              if @is_changed
                return instance_variable_get(field_name)
              end
              filename = filename_instance_method.bind(self).call
              return nil unless repodir
              return nil unless filename
              return nil if @@repo.empty?
              return nil unless fileob = current.tree.path(filename)
              oid = fileob[:oid]
              file = StringIO.new(@@repo.lookup(oid).content)
              file.seek(offset) if offset
              file.read(length)
            end
          end

          define_method(:destroy_with_file) do
            params.each do |field, filename_instance_method|
              field_name = :"@#{field}"
              filename = filename_instance_method.bind(self).call
              index = @@repo.index
              begin
                index.remove(filename)
                option = self.class.get_option(index)
                option[:message] = "Remove #{filename} for field #{field_name} of #{self.class.name}"
                Rugged::Commit.create(@@repo, option)
                @current = @@repo.head.target
                @@repo.checkout('HEAD', :strategy => :force)
                @is_changed = false
              rescue Rugged::IndexError => e
              end
            end
            destroy_without_file
          end
          define_method(:destroy) {} unless method_defined?(:destroy)
          alias_method :destroy_without_file, :destroy
          alias_method :destroy, :destroy_with_file
        end
      end
    end
  end
end
