require 'spec_helper'

describe Arachni::Reactor::Tasks::Periodic do
    it_should_behave_like 'Arachni::Reactor::Tasks::Base'

    let(:list) { Arachni::Reactor::Tasks.new }
    let(:interval) { 0.25 }
    subject { described_class.new( interval ){} }

    describe '#initialize' do
        context 'when the interval is <= 0' do
            it "raises #{ArgumentError}" do
                expect { described_class.new( 0 ){} }.to raise_error ArgumentError
                expect { described_class.new( -1 ){} }.to raise_error ArgumentError
            end
        end
    end

    describe '#interval' do
        it 'returns the configured interval' do
            subject.interval.should == interval
        end
    end

    describe '#call' do
        context 'at each interval' do
            it 'calls the task' do
                called = 0
                task = described_class.new( interval ) do
                    called += 1
                end

                time = Time.now
                task.call while called < 5

                elapsed = (Time.now - time).round(2)
                elapsed.should >= 1.25
                elapsed.should < 1.35
            end
        end

        context 'when arguments have been provided' do
            it 'passes them to the task' do
                called = nil
                task = described_class.new( interval ) do |_, s1, s2|
                    called = [s1, s2]
                end

                list << task

                task.call( :stuff1, :stuff2 ) while !called

                called.should == [:stuff1, :stuff2]
            end
        end
    end
end
