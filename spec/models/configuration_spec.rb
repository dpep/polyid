RSpec.describe "configuration" do
  describe "once a model has resolved its config" do
    before { User.polyid? }

    it "refuses settings that are baked into models" do
      expect { PolyId.auto_detect = false }.to raise_error(PolyId::ConfigurationError, /initializer/)
      expect { PolyId.default_uuid_attribute = :public_id }.to raise_error(PolyId::ConfigurationError)
    end

    it "still allows settings that are read afresh" do
      expect { PolyId.cache_ttl = 1.hour }.not_to raise_error
      expect { PolyId.uuid_generator = :v4 }.not_to raise_error
      expect { PolyId.cache = ActiveSupport::Cache::MemoryStore.new }.not_to raise_error
    end

    it "refuses a late polyid declaration, rather than ignoring it" do
      expect {
        User.polyid uuid_attribute: :something_else
      }.to raise_error(PolyId::ConfigurationError, /already resolved/)
    end
  end

  describe "before any model has resolved" do
    it "accepts configuration" do
      expect { PolyId.auto_detect = false }.not_to raise_error
      expect(PolyId.auto_detect?).to be false
    end
  end

  describe "once a model has loaded its schema" do
    before do
      model = stub_const("FreshAccount", Class.new(ActiveRecord::Base) { self.table_name = "accounts" })
      model.type_for_attribute("uuid")
    end

    it "refuses settings that are baked into models" do
      expect { PolyId.default_uuid_attribute = :public_id }.to raise_error(PolyId::ConfigurationError)
    end
  end

  describe "once a model has declared polyid" do
    before do
      Class.new(ActiveRecord::Base) do
        self.table_name = "users"
        polyid
      end
    end

    it "refuses settings that are baked into models" do
      expect { PolyId.default_uuid_attribute = :public_id }.to raise_error(PolyId::ConfigurationError)
    end
  end

  describe "a model's own settings" do
    it "stay off its instances" do
      expect(Gadget.new).not_to respond_to(
        :polyid_uuid_attribute_raw, :polyid_uuid_attribute_raw?, :polyid_uuid_generator, :polyid_uuid_generator?,
      )
    end

    it "are only written by declaring polyid" do
      expect { User.polyid_uuid_attribute_raw = "other" }.to raise_error(NoMethodError)
      expect { User.polyid_uuid_generator = :v4 }.to raise_error(NoMethodError)
    end
  end

  it "rejects an unknown uuid generator when declared, not when first used" do
    expect {
      Class.new(ActiveRecord::Base) { polyid uuid_generator: :v9 }
    }.to raise_error(ArgumentError, /unsupported/)
  end

  it "opts a model in under the default uuid attribute when auto-detection is off" do
    PolyId.auto_detect = false
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      polyid
    end

    expect(model.polyid_uuid_attribute).to eq("uuid")
  end

  describe ".reset" do
    it "makes configuration settable again" do
      User.polyid?
      expect { PolyId.auto_detect = false }.to raise_error(PolyId::ConfigurationError)

      PolyId.reset

      expect { PolyId.auto_detect = false }.not_to raise_error
    end

    it "drops resolved model config so new settings take effect" do
      expect(User.polyid?).to be true

      PolyId.reset
      PolyId.auto_detect = false

      expect(User.polyid?).to be false
    end
  end
end
