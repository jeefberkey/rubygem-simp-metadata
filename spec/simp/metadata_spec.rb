require "spec_helper"

RSpec.describe Simp::Metadata do
  it "has a version number" do
    expect(Simp::Metadata::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
