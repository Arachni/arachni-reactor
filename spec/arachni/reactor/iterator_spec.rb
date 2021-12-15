require 'spec_helper'

describe Arachni::Reactor::Iterator do

    def get_iterator
        described_class.new reactor, list, concurrency
    end

    def get_reactor
        Arachni::Reactor.new
    end

    let(:reactor) { get_reactor }
    let(:list) { %w(one two three four) }
    let(:concurrency) { list.size }
    subject { get_iterator }

    describe '#initialize' do
        context 'when the list does not respond to #to_a' do
            let(:list) { 'stuff' }

            it "raises #{ArgumentError}" do
                expect { subject }.to raise_error ArgumentError
            end
        end

        context 'when the concurrency is' do
            context '0' do
                let(:concurrency) { 0 }

                it "raises #{ArgumentError}" do
                    expect { subject }.to raise_error ArgumentError
                end
            end

            context 'less than 0' do
                let(:concurrency) { -1 }

                it "raises #{ArgumentError}" do
                    expect { subject }.to raise_error ArgumentError
                end
            end
        end
    end

    describe '#reactor' do
        it 'returns the associated Reactor' do
            subject.reactor.should == reactor
        end
    end

    describe '#concurrency' do
        let(:concurrency){ 3 }
        it 'returns the configured Reactor' do
            subject.concurrency.should == concurrency
        end
    end

    describe '#concurrency=' do
        it 'sets the iterator concurrency' do
            runner = proc do |concurrency|
                start  = nil
                finish = nil

                iter = described_class.new( get_reactor, list, concurrency )
                iter.concurrency = concurrency

                iter.reactor.run do
                    iter.each do |item, iterator|
                        start ||= Time.now

                        iter.reactor.delay 1 do
                            if item == list.last
                                finish = Time.now
                                iter.reactor.stop
                            end

                            iterator.next
                        end
                    end
                end

                finish - start
            end

            high_concurrency = list.size
            low_concurrency  = 1

            high_concurrency_time, low_concurrency_time =
                runner.call( high_concurrency ), runner.call( low_concurrency )

            low_concurrency_time.should > high_concurrency_time

            (low_concurrency_time - high_concurrency_time).to_i.should ==
                high_concurrency - low_concurrency
        end

        context 'when it is larger than the list size' do
            let(:concurrency){ 30 }

            it 'does stuff' do
                iterated = []

                reactor.run do
                    subject.each do |item, iterator|
                        iterated << item

                        reactor.delay 1 do
                            reactor.stop if item == list.last
                            iterator.next
                        end
                    end
                end

                list.should == iterated
            end
        end
    end

    describe '#each' do
        it 'iterates over the list' do
            iterated = []

            reactor.run do
                subject.each do |item, iterator|
                    iterated << item

                    reactor.stop if item == list.last
                    reactor.delay 1 do
                        iterator.next
                    end
                end
            end

            list.should == iterated
        end

        context 'when an \'after\' proc has been provided' do
            it 'is called when the iteration is complete' do
                iterated = []

                reactor.run do
                    subject.each(
                        proc do |item, iterator|
                            iterated << item
                            reactor.delay 1 do
                                iterator.next
                            end
                        end,
                        proc do
                            reactor.stop
                        end
                    )
                end

                list.should == iterated
            end
        end
    end

    describe '#map' do
        it 'collects the results of each iteration' do
            results = nil

            reactor.run do
                subject.map(
                    proc do |string, iterator|
                        reactor.delay 1 do
                            iterator.return( string.size )
                        end
                    end,
                    proc do |res|
                        results = res
                        reactor.stop
                    end
                )
            end

            results.should == list.map(&:size)
        end
    end

    describe '#inject' do
        it 'injects the results of the iteration into the given object' do
            results = nil

            reactor.run do
                subject.inject( {},
                    proc do |hash, string, iterator|
                        hash.merge!( string => string.size )
                        iterator.return( hash )
                    end,
                    proc do |res|
                        results = res
                        reactor.stop
                    end
                )
            end

            results.should == list.inject({}) { |h, string| h.merge( string => string.size ) }
        end
    end
end
