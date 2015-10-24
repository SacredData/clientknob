# knob.rb
require "pathname"
require "json"

class Knob
  def initialize(wavfile,source)
    @file       = File.open("#{wavfile}","r")
    @file_path  = Pathname.new(@file.path)
    @source     = source
    @file_score = 0
    @levelvals  = {:flat => 1.0,   :crest => 6.0, :peak => -3.0, :rms => -16.0}
    @encodevals = {:sampleEnc => [16,24,32], :sampleDep => [16,24,32], :sampleRate => 
                  [44100,48000,96000], :channels => [1,2]}
    @issues     = []
    @validation = false
  end
  attr_reader :file, :file_path, :file_score
  def scan
    puts "Audio encoding compliance scanning"
    counter      = 1
    soxi_checks  = ["-t","-r","-c","-D","-b"]
    encCmd       = []
    soxi_checks.each do |cmd|
      encCmd[counter] = `soxi #{cmd} "#{@file_path}"`
      puts "#{counter}: #{encCmd[counter]}"
      counter += 1
    end
    @enc = {:sample_encoding => "#{encCmd[5]}".to_i, :sample_depth => "#{encCmd[5]}".to_i, 
     :sample_rate => "#{encCmd[2]}".to_i, :channels => "#{encCmd[3]}".to_i}
    puts "Audio dynamics measurement scanning"
    statsCmd = `sox "#{@file_path}" -n stats 2>&1`
    # THERE IS A BUG!! FIX IT!! THE LINE NUMBER MUST CHANGE WHEN THE FILE IS STEREO/MONO!!!!
    @seconds = "#{statsCmd.split("\n")[-3]}".match(/\d+.\d+/)[0].to_f   # length in seconds
    @flat    = "#{statsCmd.split("\n")[-7]}".match(/\d+.\d+/)[0].to_f   # number of samples that hit 0dBFS
    @crest   = "#{statsCmd.split("\n")[-8]}".match(/\d+.\d+/)[0].to_f   # peak-to-RMS ratio
    @rms     = "#{statsCmd.split("\n")[-11]}".match(/-\d+.\d+/)[0].to_f # look it up on wikipedia
    @peak    = "#{statsCmd.split("\n")[-12]}".match(/-\d+.\d+/)[0].to_f # loudest measured sample in the file
    @stats = {:flat => @flat, :crest => @crest, :peak => @peak, :rms => @rms,
      :seconds => @seconds}
    puts "Warnings"
    @issues.push("rms_high")   if "#{@rms}".to_f > -16.0
    @issues.push("peaks")      if "#{@peak}".to_f > -4.0
    score
  end
  attr_reader :sampleEnc, :sampleDep, :sampleRate, :channels
  def score
    puts "Audio encoding compliance scoring"
    @file_score += 10 if 
      @encodevals[:sampleRate].any? {|rate| rate == "#{@sampleRate}".to_i} == true &&
      @encodevals[:sampleEnc].any?  {|enc| enc == "#{@sampleEnc}".to_i}    == true &&
      @encodevals[:sampleDep].any?  {|dep| dep == "#{@sampleDep}".to_i}    == true &&
      @encodevals[:channels].any?   {|chan| chan == "#{@channels}".to_i}   == true
    puts "Audio dynamics measurement scoring"
    @file_score   += 10 if "#{@flat}".to_f  < @levelvals[:flat]  #else @issues.push("flat")
    @file_score   += 10 if "#{@peak}".to_f  < @levelvals[:peak]  #else @issues.push("peak")
    @file_score   += 5  if "#{@crest}".to_f > @levelvals[:crest] #else @issues.push("crest")
    @file_score   += 15 if "#{@rms}".to_f   < @levelvals[:rms]   #else @issues.push("rms")
    puts "Finish up and return json msg"
    @validation = true   if @file_score  >= 50
    @issues.push("none") if @issues.size == 0
    return {:file => "#{@source}", :pass => "#{@validation}",
            :score => @file_score, :enc  => @enc, :stats => @stats,
            :issues => @issues}.to_json
    end
  attr_reader :pass, :flat, :crest, :peak, :rms, :seconds, :issues
end