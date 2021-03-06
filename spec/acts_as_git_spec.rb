require_relative 'spec_helper'
require_relative 'model'

describe ActsAsGit do
  let(:subject) { TestPost.new }
  after do
    path = subject.path(:body)
    File.unlink(path) if File.exist?(path)
  end

  after(:context) do
    FileUtils.rm_rf(File.join(TestPost.repodir, '.git')) if Dir.exist?(File.join(TestPost.repodir, '.git'))
  end

  context '#log' do
    let(:commits) { [] }
    before { subject.body = 'aaaa' }
    before { subject.save }
    before { commits << subject.current }
    before { subject.body = 'bbbb' }
    before { subject.save }
    before { commits << subject.current }
    before { subject.body = 'cccc' }
    before { subject.save }
    before { commits << subject.current }
    it { expect(subject.log(:body)).to be == commits.reverse }
  end

  context '#body=' do
    it { expect { subject.body = 'aaaa' }.not_to raise_error }
  end

  context '#body' do
    context 'get from instance variable' do
      before { subject.body = 'aaaa' }
      its(:body) { should == 'aaaa' }
    end

    context 'get from file' do
      before { subject.body = 'aaaa' }
      before { subject.save }
      its(:body) { should == 'aaaa' }
    end

    context 'seek' do
      before { subject.body = 'abcd' }
      before { subject.save }
      it { expect(subject.body(1, 2)).to be == 'bc' }
    end

    context 'get from commit in the past' do
      before do
        subject.body = 'aaaa'
        subject.save
        @commit = subject.current
        subject.body = 'bbbb'
        subject.save
      end
      it { expect(subject.body).to be == 'bbbb' }
      it do
        subject.checkout(@commit)
        expect(subject.body).to be == 'aaaa'
      end
    end
  end
  
  context '#save_with_file' do
    context 'save if body exists' do
      before { subject.body = 'aaaa' }
      before { subject.save }
      it { expect(File.read(subject.path(:body))).to eql('aaaa') }
    end

    context 'does not save if body does not exist' do
      before { subject.body = nil }
      before { subject.save }
      it { expect(File.exist?(subject.path(:body))).to be_falsey }
    end
  end

  context '#destroy_with_file' do
    context 'delete if file exists' do
      before { subject.body = 'aaaa' }
      before { subject.save }
      before { subject.destroy }
      it { expect(File.exist?(subject.path(:body))).to be_falsey }
    end

    context 'fine even if file does not exist' do
      before { subject.destroy }
      it { expect(File.exist?(subject.path(:body))).to be_falsey }
    end
  end
end

