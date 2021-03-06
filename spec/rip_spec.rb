require 'spec_helper'

describe Rip do
  describe '.project_path' do
    its(:project_path) { should eq(Pathname(Dir.pwd).expand_path) }
  end

  describe '.project_path=' do
    around(:each) do |it_block|
      default_path = Rip.project_path
      Rip.project_path = 'some/other/directory'
      it_block.call
      Rip.project_path = default_path
    end

    its(:project_path) { should eq(Pathname('some/other/directory').expand_path) }
  end

  describe '.root' do
    its(:root) { should eq(Pathname('lib').expand_path) }
  end
end
