require 'spec_helper'

# Intercept the hook that sensu uses to auto-execute checks by entirely replacing
# the method used in Kernel before loading the handler.
# This is _terrible_, see also https://github.com/sensu/sensu-plugin/pull/61
module Kernel
  def at_exit(&block)
  end
end

require "#{File.dirname(__FILE__)}/../../files/hipchat"

class Hipchat
  attr_accessor :settings
end

describe Hipchat do
  include SensuHandlerTestHelper

  subject { described_class.new }
  before(:each) do
    setup_event!
    subject.event['check']['team'] = 'Slumbering Dropbears'
    HipChat::Room.any_instance.stubs(:send)
  end

  # two silly tests just for starter
  it { expect(subject).to be_a BaseHandler }
  it { expect(subject).to be_a Sensu::Handler }

  describe 'trigger_incident' do
    it 'returns false when no hipchat api_key' do
      expect(subject.trigger_incident).to be false
    end

    it 'calls alert_hipchat when hipchat api_key exists' do
      subject.settings['hipchat']['apikey'] = 'fakekey'
      subject.event['check']['status'] = 2

      expect(subject).to receive(:alert_hipchat).with({ :color => "red", :notify => true })
      subject.trigger_incident
    end
  end

  describe 'resolve_incident' do
    it 'returns false when no hipchat api_key' do
      expect(subject.resolve_incident).to be false
    end

    it 'calls alert_hipchat when hipchat api_key exists' do
      subject.settings['hipchat']['apikey'] = 'fakekey'
      subject.event['check']['status'] = 0

      expect(subject).to receive(:alert_hipchat).with({ :color => 'green' })
      subject.resolve_incident
    end
  end

  describe 'handle' do
    context 'when check status is 0' do
      before do
        subject.event['check']['status'] = 0
      end

      context 'when resolve_incident returns true' do
        it 'calls resolve_incident once' do
          expect(subject).to receive(:resolve_incident)
            .once
            .and_return(true)

          subject.handle
        end

        it 'calls alert_hipchat with options color green' do
          expect(subject).to receive(:alert_hipchat)
            .with( { :color => 'green' } )
            .and_return(true)

          subject.handle
        end
      end

      context 'when resolve_incident returns false' do
        it 'calls resolve_incident 3 times' do
          expect(subject).to receive(:resolve_incident)
            .exactly(3).times
            .and_return(false)

          subject.handle
        end
      end
    end

    context 'when check status is 1' do
      before do
        subject.event['check']['status'] = 1
      end

      context 'when trigger_incident returns true' do
        it 'calls trigger_incident once' do
          expect(subject).to receive(:trigger_incident)
            .once
            .and_return(true)

          subject.handle
        end
      end

      context 'when trigger_incident returns false' do
        it 'calls trigger_incident 3 times' do
          expect(subject).to receive(:trigger_incident)
            .exactly(3).times
            .and_return(false)

          subject.handle
        end
      end

      it 'calls alert_hipchat with options color yellow & notify true' do
        expect(subject).to receive(:alert_hipchat)
          .with( { :color => 'yellow', :notify => true } )
          .and_return(true)

        subject.handle
      end
    end

    context 'when check status is 2' do
      before do
        subject.event['check']['status'] = 2
      end

      context 'when trigger_incident returns true' do
        it 'calls trigger_incident once' do
          expect(subject).to receive(:trigger_incident)
            .once
            .and_return(true)

          subject.handle
        end
      end

      # context 'when trigger_incident returns false' do
      #   it 'calls trigger_incident 3 times' do
      #     expect(subject).to receive(:trigger_incident)
      #       .exactly(3).times
      #       .and_return(false)
      #
      #     subject.handle
      #   end
      # end

      it 'calls alert_hipchat with options color red & notify true' do
        expect(subject).to receive(:alert_hipchat)
          .with( { :color => 'red', :notify => true } )
          .and_return(true)

        subject.handle
      end
    end
  end

  describe 'hipchat_message' do
    before do
      subject.event['check']['name'] = 'Fake Service port 80'
      subject.event['check']['issued'] = 1438866190
      subject.event['client']['name'] = 'test.vagrant.local'
      subject.event['client']['address'] = '127.0.0.1'
    end

    it 'correctly formats the check issued date' do
      expect(subject.hipchat_message).to include('2015-08-06 14:03:10 +0100')
    end

    it 'correctly formats the line containing datetime, service, host and address' do
      expect(subject.hipchat_message)
        .to include('2015-08-06 14:03:10 +0100 - Fake Service port 80 on test.vagrant.local (127.0.0.1)')
    end

    context 'when check notification is populated' do
      it 'contains the notifcation data' do
        expect(subject.hipchat_message).to include('some check output')
      end
    end

    context 'when check notification is absent from sensu data' do
      before do
        subject.event['check']['output'] = 'TCP OK - 0.019 second response time on port 80'
        subject.event['check'].delete('notification')
      end

      it 'contains the check output' do
        expect(subject.hipchat_message).to include('TCP OK - 0.019 second response time on port 80')
      end
    end

    context 'human readable message status' do
      context 'when status is 0' do
        before do
          subject.event['check']['status'] = 0
        end

        it 'status message is OK' do
          expect(subject.hipchat_message).to include(' - OK')
        end
      end

      context 'when status is 1' do
        before do
          subject.event['check']['status'] = 1
        end

        it 'status message is WARNING' do
          expect(subject.hipchat_message).to include(' - WARNING')
        end
      end

      context 'when status is 2' do
        before do
          subject.event['check']['status'] = 2
        end

        it 'status message is CRITICAL' do
          expect(subject.hipchat_message).to include(' - CRITICAL')
        end
      end

      context 'when status is 3' do
        before do
          subject.event['check']['status'] = 3
        end

        it 'status message is UNKNOWN' do
          expect(subject.hipchat_message).to include(' - UNKNOWN')
        end
      end
    end
  end
end