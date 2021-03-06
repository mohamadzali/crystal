#!/usr/bin/env bin/crystal --run
require "spec"
require "option_parser"

describe "OptionParser" do
  def expect_capture_option(args, option, value)
    flag = nil
    OptionParser.parse(args) do |opts|
      opts.on(option, "some flag") do |flag_value|
        flag = flag_value
      end
    end
    flag.should eq(value)
    args.length.should eq(0)
  end

  def expect_doesnt_capture_option(args, option)
    flag = false
    OptionParser.parse(args) do |opts|
      opts.on(option, "some flag") do
        flag = true
      end
    end
    flag.should be_false
  end

  def expect_missing_option(option)
    OptionParser.parse([] of String) do |opts|
      opts.on(option, "some flag") do |flag_value|
      end
    end
    fail "expected OptionParser::MissingOption to be raised"
  rescue ex : OptionParser::MissingOption
  end

  def expect_missing_option(args, option, flag)
    OptionParser.parse(args) do |opts|
      opts.on(option, "some flag") do |flag_value|
      end
    end
    fail "expected OptionParser::MissingOption to be raised"
  rescue ex : OptionParser::MissingOption
    ex.message.should eq("Missing option: #{flag}")
  end

  it "has flag" do
    expect_capture_option ["-f"], "-f", ""
  end

  it "has flag with many letters" do
    expect_capture_option ["-ll"], "-ll", "l"
  end

  it "doesn't have flag" do
    expect_doesnt_capture_option ([] of String), "-f"
  end

  it "has flag with double dash" do
    expect_capture_option ["--flag"], "--flag", ""
  end

  it "doesn't have flag with double dash" do
    expect_doesnt_capture_option ([] of String), "--flag"
  end

  it "has required option next to flag" do
    expect_capture_option ["-f123"], "-fFLAG", "123"
  end

  it "raises if missing option next to flag" do
    expect_missing_option ["-f"], "-fFLAG", "-f"
  end

  it "has required option separated from flag" do
    expect_capture_option ["-f", "123"], "-f FLAG", "123"
  end

  it "gets short option with value that looks like flag" do
    expect_capture_option ["-f", "-g -h"], "-f FLAG", "-g -h"
  end

  it "raises if missing required option with space" do
    expect_missing_option ["-f"], "-f FLAG", "-f"
  end

  it "has required option separated from long flag" do
    expect_capture_option ["--flag", "123"], "--flag FLAG", "123"
  end

  it "raises if missing required argument separated from long flag" do
    expect_missing_option ["--flag"], "--flag FLAG", "--flag"
  end

  it "has required option with space" do
    expect_capture_option ["-f", "123"], "-f ", "123"
  end

  it "has required option with long flag space" do
    expect_capture_option ["--flag", "123"], "--flag ", "123"
  end

  it "doesn't raise if required option is not specified" do
    expect_doesnt_capture_option ([] of String), "-f "
  end

  it "doesn't raise if optional option is not specified with short flag" do
    expect_doesnt_capture_option ([] of String), "-f[FLAG]"
  end

  it "doesn't raise if optional option is not specified with long flag" do
    expect_doesnt_capture_option ([] of String), "--flag [FLAG]"
  end

  it "doesn't raise if optional option is not specified with separated short flag" do
    expect_doesnt_capture_option ([] of String), "-f [FLAG]"
  end

  it "doesn't raise if required option is not specified with separated short flag 2" do
    expect_doesnt_capture_option ([] of String), "-f FLAG"
  end

  it "does to_s with banner" do
    parser = OptionParser.parse([] of String) do |opts|
      opts.banner = "Usage: foo"
      opts.on("-f", "--flag", "some flag") do
      end
      opts.on("-g[FLAG]", "some other flag") do
      end
    end
    parser.to_s.should eq([
      "Usage: foo",
      "    -f, --flag                       some flag"
      "    -g[FLAG]                         some other flag"
    ].join "\n")
  end

  it "raises on invalid option" do
    begin
      OptionParser.parse(["-f", "-j"]) do |opts|
        opts.on("-f", "some flag") { }
      end
      fail "Expected to raise OptionParser::InvalidOption"
    rescue ex : OptionParser::InvalidOption
      ex.message.should eq("Invalid option: -j")
    end
  end
end
