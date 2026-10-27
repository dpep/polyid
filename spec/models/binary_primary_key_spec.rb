RSpec.describe "a binary uuid primary key" do
  it "is not polyid" do
    expect(Token.polyid?).to be false
  end

  it "keeps bytes that are not an RFC uuid" do
    bytes = "\x00".b * 16

    expect(Token.create!(uuid: bytes).reload.uuid).to eq(bytes)
  end
end
