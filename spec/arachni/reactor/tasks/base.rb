require 'spec_helper'

describe Arachni::Reactor::Tasks::Base do
    it_should_behave_like 'Arachni::Reactor::Tasks::Base'

    subject { described_class.new{} }
end

