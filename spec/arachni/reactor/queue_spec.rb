require 'spec_helper'

describe Arachni::Reactor::Queue do
    let(:reactor) { Arachni::Reactor.new }
    subject { described_class.new reactor }

    describe '#initialize' do
        it 'sets the associated reactor' do
            subject.reactor.should == reactor
        end
    end

    describe '#pop' do
        context 'when the queue is not empty' do
            it 'passes the next item to the block' do
                passed_item = nil

                reactor.run do
                    subject << :my_item
                    subject.pop do |item|
                        passed_item = item
                        reactor.stop
                    end
                end

                passed_item.should == :my_item
            end
        end

        context 'when the queue is empty' do
            it 'assigns a block to handle new items' do
                passed_item = nil

                reactor.run do
                    subject.pop do |item|
                        passed_item = item
                        reactor.stop
                    end

                    subject << :my_item
                end

                passed_item.should == :my_item
            end
        end
    end

    describe '#empty?' do
        context 'when the queue is empty' do
            it 'returns true' do
                subject.should be_empty
            end
        end

        context 'when the queue is not empty' do
            it 'returns false' do
                reactor.run_block do
                    subject << nil
                    subject.should_not be_empty
                end
            end
        end
    end

    describe '#size' do
        it 'returns the queue size' do
            reactor.run_block do
                2.times { |i| subject << i }
                subject.size.should == 2
            end
        end
    end

    describe '#num_waiting' do
        context 'when no jobs are available to handle new items' do
            it 'returns 0' do
                subject.num_waiting.should == 0
            end
        end

        context 'when there are jobs waiting to handle new items' do
            it 'returns a count' do
                reactor.run_block do
                    3.times { subject.pop{} }
                    subject.num_waiting.should == 3
                end
            end
        end
    end

end
