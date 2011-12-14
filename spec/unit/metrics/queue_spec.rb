require "spec_helper.rb"

module Librato
  module Metrics

    describe Queue do

      describe "#add" do

        context "with single hash argument" do
          it "should record a key-value gauge" do
            subject.add :foo => 3000
            subject.queued.should eql({:gauges => [{:name => 'foo', :value => 3000}]})
          end
        end

        context "with specified metric type" do
          it "should record counters" do
            subject.add :total_visits => {:type => :counter, :value => 4000}
            expected = {:counters => [{:name => 'total_visits', :value => 4000}]}
            subject.queued.should eql expected
          end

          it "should record gauges" do
            subject.add :temperature => {:type => :gauge, :value => 34}
            expected = {:gauges => [{:name => 'temperature', :value => 34}]}
            subject.queued.should eql expected
          end

          it "should accept type key as string or a symbol" do
            subject.add :total_visits => {"type" => "counter", :value => 4000}
            expected = {:counters => [{:name => 'total_visits', :value => 4000}]}
            subject.queued.should eql expected
          end
        end

        context "with extra attributes" do
          it "should record" do
            measure_time = Time.now
            subject.add :disk_use => {:value => 35.4, :period => 2,
              :description => 'current disk utilization', :measure_time => measure_time,
              :source => 'db2'}
            expected = {:gauges => [{:value => 35.4, :name => 'disk_use', :period => 2,
              :description => 'current disk utilization', :measure_time => measure_time,
              :source => 'db2'}]}
            subject.queued.should eql expected
          end
        end

        context "with multiple metrics" do
          it "should record" do
            subject.add :foo => 123, :bar => 345, :baz => 567
            expected = {:gauges=>[{:name=>"foo", :value=>123}, {:name=>"bar", :value=>345}, {:name=>"baz", :value=>567}]}
            subject.queued.should eql expected
          end
        end

      end

      describe "#counters" do

        it "should return currently queued counters" do
          subject.add :transactions => {:type => :counter, :value => 12345},
                        :register_cents => {:type => :gauge, :value => 211101}
          subject.counters.should eql [{:name => 'transactions', :value => 12345}]
        end

        it "should return [] when no queued counters" do
          subject.counters.should eql []
        end

      end

      describe "#gauges" do

        it "should return currently queued gauges" do
          subject.add :transactions => {:type => :counter, :value => 12345},
                        :register_cents => {:type => :gauge, :value => 211101}
          subject.gauges.should eql [{:name => 'register_cents', :value => 211101}]
        end

        it "should return [] when no queued gauges" do
          subject.gauges.should eql []
        end

      end

      describe "#submit" do

        before(:all) do
          Librato::Metrics.authenticate 'me@librato.com', 'foo'
          Librato::Metrics.persistence = :test
        end
        after(:all) { Librato::Metrics::Simple.flush_authentication }

        context "when successful" do
          it "should flush queued metrics and return true" do
            subject.add :steps => 2042, :distance => 1234
            subject.submit.should be_true
            subject.queued.should be_empty
          end
        end

        context "when failed" do
          it "should preserve queue and return false" do
            subject.add :steps => 2042, :distance => 1234
            subject.persister.return_value(false)
            subject.submit.should be_false
            subject.queued.should_not be_empty
          end
        end

      end

      describe "#time" do

        context "with metric name only" do

          it "should queue metric with timed value" do
            subject.time :sleeping do
              sleep 0.1
            end
            queued = subject.queued[:gauges][0]
            queued[:name].should == 'sleeping'
            queued[:value].should be > 100
            queued[:value].should be_within(30).of(100)
          end

        end

        context "with metric and options" do

          it "should queue metric with value and options" do
            subject.time :sleep_two, :source => 'app1', :period => 2 do
              sleep 0.05
            end
            queued = subject.queued[:gauges][0]
            queued[:name].should == 'sleep_two'
            queued[:period].should == 2
            queued[:source].should == 'app1'
            queued[:value].should be > 50
            queued[:value].should be_within(30).of(50)
          end

        end

      end

    end # MetricSet

  end
end
