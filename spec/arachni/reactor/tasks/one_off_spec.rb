require 'spec_helper'

describe Arachni::Reactor::Tasks::OneOff do
    it_should_behave_like 'Arachni::Reactor::Tasks::Base'

    let(:list) { Arachni::Reactor::Tasks.new }
    subject { described_class.new{} }

    describe '#initialize' do
        context 'when no task have been given' do
            it "raises #{ArgumentError}" do
                expect { described_class.new }.to raise_error ArgumentError
            end
        end
    end

    describe '#call' do
        it 'calls the given task' do
            callable = proc {}
            callable.should receive(:call)

            task = described_class.new(&callable)
            list << task

            task.call
        end

        it 'passes the task to it' do
            callable = proc {}
            task = described_class.new(&callable)

            callable.should receive(:call).with(task)

            list << task

            task.call
        end

        it 'calls #done' do
            callable = proc {}
            task = described_class.new(&callable)

            callable.should receive(:call).with(task)

            list << task

            task.should receive(:done)
            task.call
        end

        context 'when arguments have been provided' do
            it 'passes them to the task' do
                got = nil
                callable = proc do |_, arg|
                    got = arg
                end

                task = described_class.new(&callable)
                list << task

                task.call :stuff
                got.should == :stuff
            end
        end
    end
end
