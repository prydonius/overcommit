require 'spec_helper'
require 'overcommit/hook_context/post_merge'

describe Overcommit::HookContext::PostMerge do
  let(:config) { double('config') }
  let(:args) { [] }
  let(:context) { described_class.new(config, args) }

  describe '#squash?' do
    subject { context.squash? }

    context 'when the merge is made using --squash' do
      let(:args) { [1] }

      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          `git commit --allow-empty -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --squash child`
          example.run
        end
      end

      it { should == true }
    end

    context 'when the merge is made without --squash' do
      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          `git commit --allow-empty -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should == false }
    end
  end

  describe '#merge_commit?' do
    subject { context.merge_commit? }

    context 'when the merge is made using --squash' do
      let(:args) { [1] }

      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          `git commit --allow-empty -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --squash child`
          example.run
        end
      end

      it { should == false }
    end

    context 'when the merge is made without --squash' do
      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          `git commit --allow-empty -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should == true }
    end
  end

  describe '#modified_files' do
    subject { context.modified_files }

    it 'does not include submodules' do
      submodule = repo do
        `touch foo`
        `git add foo`
        `git commit -m "Initial commit"`
      end

      repo do
        `git commit --allow-empty -m "Initial commit"`
        `git checkout -b child &> /dev/null`
        `git submodule add #{submodule} test-sub 2>&1 > /dev/null`
        `git commit -m "Add submodule"`
        `git checkout master &> /dev/null`
        `git merge --no-ff --no-edit child`
        expect(subject).to_not include File.expand_path('test-sub')
      end
    end

    context 'when no files were staged' do
      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          `git commit --allow-empty -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should be_empty }
    end

    context 'when files were added' do
      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          FileUtils.touch('some-file')
          `git add some-file`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should == [File.expand_path('some-file')] }
    end

    context 'when files were modified' do
      around do |example|
        repo do
          FileUtils.touch('some-file')
          `git add some-file`
          `git commit -m 'Initial commit'`
          `git checkout -b child &> /dev/null`
          `echo Hello > some-file`
          `git add some-file`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should == [File.expand_path('some-file')] }
    end

    context 'when files were deleted' do
      around do |example|
        repo do
          FileUtils.touch('some-file')
          `git add some-file`
          `git commit -m 'Initial commit'`
          `git checkout -b child &> /dev/null`
          `git rm some-file`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should be_empty }
    end

    context 'when the merge is made using --squash' do
      let(:args) { [1] }

      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          FileUtils.touch('some-file')
          `git add some-file`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --squash child`
          example.run
        end
      end

      it { should == [File.expand_path('some-file')] }
    end
  end

  describe '#modified_lines_in_file' do
    let(:modified_file) { 'some-file' }
    subject { context.modified_lines_in_file(modified_file) }

    context 'when file contains a trailing newline' do
      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          File.open(modified_file, 'w') { |f| (1..3).each { |i| f.write("#{i}\n") } }
          `git add #{modified_file}`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should == Set.new(1..3) }
    end

    context 'when file does not contain a trailing newline' do
      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          File.open(modified_file, 'w') do |f|
            (1..2).each { |i| f.write("#{i}\n") }
            f.write(3)
          end
          `git add #{modified_file}`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --no-ff --no-edit child`
          example.run
        end
      end

      it { should == Set.new(1..3) }
    end

    context 'when the merge is made using --squash' do
      let(:args) { [1] }

      around do |example|
        repo do
          `git commit --allow-empty -m "Initial commit"`
          `git checkout -b child &> /dev/null`
          File.open(modified_file, 'w') { |f| (1..3).each { |i| f.write("#{i}\n") } }
          `git add #{modified_file}`
          `git commit -m "Branch commit"`
          `git checkout master &> /dev/null`
          `git merge --squash child`
          example.run
        end
      end

      it { should == Set.new(1..3) }
    end
  end
end
