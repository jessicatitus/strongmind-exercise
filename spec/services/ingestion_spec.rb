require "rails_helper"

RSpec.describe EventIngestionService do
  subject(:service) { described_class.new(client: client) }
  let(:client)      { instance_double(GithubClient) }

  let(:push_event_raw) do
    {
      "id"      => "abc123",
      "type"    => "PushEvent",
      "actor"   => { "id" => 1, "login" => "octocat", "url" => "https://api.github.com/users/octocat" },
      "repo"    => { "id" => 9, "name" => "octocat/hello-world", "url" => "https://api.github.com/repositories/9" },
      "payload" => {
        "push_id" => 42,
        "ref"     => "refs/heads/main",
        "head"    => "abc",
        "before"  => "def"
      }
    }
  end

  describe "#call" do
    context "with a valid PushEvent" do
      it "persists the event with structured fields" do
        service.call([push_event_raw])
        event = PushEvent.find_by!(github_event_id: "abc123")
        expect(event.repo_identifier).to eq("octocat/hello-world")
        expect(event.ref).to eq("refs/heads/main")
        expect(event.head).to eq("abc")
        expect(event.before).to eq("def")
      end

      it "retains the raw payload for audit" do
        service.call([push_event_raw])
        event = PushEvent.find_by!(github_event_id: "abc123")
        expect(event.raw_payload).to eq(push_event_raw)
      end

      it "enqueues an enrichment job" do
        expect(EnrichPushEventJob).to receive(:perform_later).once
        service.call([push_event_raw])
      end

      it "reports the correct counts" do
        result = service.call([push_event_raw])
        expect(result.ingested).to eq(1)
        expect(result.skipped).to eq(0)
        expect(result.errors).to be_empty
      end
    end

    context "with a duplicate event" do
      before { service.call([push_event_raw]) }

      it "does not create a duplicate record" do
        expect { service.call([push_event_raw]) }
          .not_to change(PushEvent, :count)
      end

      it "reports the event as skipped" do
        result = service.call([push_event_raw])
        expect(result.skipped).to eq(1)
        expect(result.ingested).to eq(0)
      end

      it "does not enqueue a second enrichment job" do
        expect(EnrichPushEventJob).not_to receive(:perform_later)
        service.call([push_event_raw])
      end
    end

    context "with non-PushEvent types" do
      let(:watch_event) { push_event_raw.merge("type" => "WatchEvent") }
      let(:fork_event)  { push_event_raw.merge("type" => "ForkEvent", "id" => "xyz999") }

      it "ignores non-PushEvent types" do
        expect { service.call([watch_event, fork_event]) }
          .not_to change(PushEvent, :count)
      end
    end

    context "with malformed events" do
      let(:malformed) { { "id" => "bad1", "type" => "PushEvent" } }

      it "records the error and continues" do
        result = service.call([malformed, push_event_raw])
        expect(result.errors.size).to eq(1)
        expect(result.ingested).to eq(1)
      end
    end
  end
end
