require 'spec_helper'

describe Arachni::Reactor::Tasks do
    subject { described_class.new }
    let(:task) { described_class::Persistent.new{} }
    let(:another_task) { described_class::Persistent.new{} }

    describe '#<<' do
        it 'adds a task to the list' do
            subject << task
            subject.should include task
        end

        it 'assigns an #owner to the task' do
            subject << task
            task.owner.should == subject
        end

        it 'returns self' do
            (subject << task).should == subject
        end
    end

    describe '#include?' do
        context 'when it includes the given task' do
            it 'returns true' do
                subject << task
                expect(subject.include?( task )).to be_truthy
            end
        end

        context 'when it does not includes the given task' do
            it 'returns false' do
                subject << task
                expect(subject.include?( another_task )).to be_falsey
            end
        end
    end

    describe '#delete' do
        context 'when it includes the given task' do
            it 'removes it' do
                subject << task
                subject.delete task
                subject.should_not include task
            end

            it 'returns it' do
                subject << task
                subject.delete( task ).should == task
            end

            it 'removes the #owner association' do
                subject << task
                subject.delete( task ).should == task
                task.owner.should be_nil
            end
        end

        context 'when it does not include the given task' do
            it 'returns nil' do
                subject.delete( task ).should be_nil
            end
        end
    end

    describe '#size' do
        it 'returns the size of the list' do
            subject << task
            subject << another_task
            subject.size.should == 2
        end
    end

    describe '#empty?' do
        context 'when the list is empty' do
            it 'returns true' do
                subject.should be_empty
            end
        end

        context 'when the list is not empty' do
            it 'returns false' do
                subject << task
                subject.should_not be_empty
            end
        end
    end

    describe '#any?' do
        context 'when the list is not empty' do
            it 'returns true' do
                subject << task
                subject.should be_any
            end
        end

        context 'when the list is empty' do
            it 'returns false' do
                subject.should_not be_any
            end
        end
    end

    describe '#clear' do
        it 'removes all tasks' do
            subject << task
            subject << another_task
            subject.clear
            subject.should be_empty
        end
    end

    describe '#call' do
        it 'calls all tasks' do
            called_one = false
            called_two = false

            subject << described_class::Persistent.new do
                called_one = true
            end
            subject << described_class::Persistent.new do
                called_two = true
            end

            subject.call

            called_one.should be_truthy
            called_two.should be_truthy
        end

        it 'returns self' do
            subject.call.should == subject
        end

        context 'when arguments have been provided' do
            it 'passes them to the tasks' do
                called_one = nil
                called_two = nil

                subject << described_class::Persistent.new do |_, arg|
                    called_one = arg
                end
                subject << described_class::Persistent.new do |_, arg|
                    called_two = arg
                end

                subject.call( :stuff )

                called_one.should == :stuff
                called_two.should == :stuff
            end
        end
    end
end
