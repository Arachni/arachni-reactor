require 'spec_helper'

describe Arachni::Reactor::Tasks::Delayed do
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
        context 'at the next interval' do
            it 'calls the task' do
                called = 0
                task = described_class.new( interval ) do
                    called += 1
                end

                list << task

                time = Time.now
                task.call while called < 1

                elapsed = (Time.now - time).round(2)
                elapsed.should >= 0.25
                elapsed.should < 0.30
            end

            it 'calls #done' do
                called = 0
                task = described_class.new( interval ) do
                    called += 1
                end

                list << task

                task.should receive(:done)
                task.call while called < 1
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
end
