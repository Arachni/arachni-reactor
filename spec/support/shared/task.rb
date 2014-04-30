shared_examples_for 'Arachni::Reactor::Tasks::Base' do
    let(:list) { Arachni::Reactor::Tasks.new }

    it { should respond_to :owner }
    it { should respond_to :owner= }

    describe '#done' do
        it 'removes self from the #owner' do
            list << subject
            subject.done
            list.should_not include subject
        end
    end

end
