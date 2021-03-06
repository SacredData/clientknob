# knob.rb
require "pathname"
require "json"

class Knob
  def initialize(wavfile,source)
    KnobLog.log.info "Initializing audio file analysis..."
    @file_path  = Pathname.new(File.open("#{wavfile}","r"))
    @source     = source
    @file_score = 0
    @levelvals  = {:flat => 1.0,   :crest => 6.0, :peak => -3.0, :rms => -16.0}
    @encodevals = {:sampleEnc  => [16,24,32], :sampleDep => [16,24,32],
                   :sampleRate => [44100,48000,96000], :channels => [1,2]}
    @issues     = []
  end
  attr_reader :file_path, :file_score
  def scan
    # Audio encoding compliance scanning
    counter      = 1
    soxi_checks  = ["-t","-r","-c","-D","-b"]
    encCmd       = []
    soxi_checks.each do |cmd|
      encCmd[counter] = `soxi #{cmd} "#{@file_path}"`
      KnobLog.log.info "#{counter}: #{encCmd[counter]}"
      counter += 1
    end
    if encCmd[1] =~ /(wav|flac|aif|aiff)/
      @lossless = true
    else
      @lossless = false
    end
    @enc = {:sample_encoding => "#{encCmd[5]}".to_i, :sample_depth => "#{encCmd[5]}".to_i,
            :sample_rate => "#{encCmd[2]}".to_i, :channels => "#{encCmd[3]}".to_i, :lossless => @lossless}
    # Audio dynamics measurement scanning
    statsCmd = `sox "#{@file_path}" -n stats spectrogram -o "public/spectrogram/#{@source}.png" 2>&1`
    @seconds = "#{statsCmd.split("\n")[-3]}".match(/\d+.\d+/)[0].to_f
    @flat    = "#{statsCmd.split("\n")[-7]}".match(/\d+.\d+/)[0].to_f
    @crest   = "#{statsCmd.split("\n")[-8]}".match(/\d+.\d+/)[0].to_f
    @rms     = "#{statsCmd.split("\n")[-11]}".match(/-?\d+.\d+/)[0].to_f
    @peak    = "#{statsCmd.split("\n")[-12]}".match(/-?\d+.\d+/)[0].to_f
    @stats = {:flat => @flat, :crest => @crest, :peak => @peak, :rms => @rms,
              :seconds => @seconds}
    # Warnings
    @issues.push("rms_high")   if "#{@rms}".to_f > -16.0
    @issues.push("peaks")      if "#{@peak}".to_f > -4.0
    score
  end
  attr_reader :enc, :stats
  def score
    KnobLog.log.info "Initializing audio file scoring..."
    # Audio encoding evaluation
    @file_score += 10 if @lossless == true
    @file_score += 10 if
      @encodevals[:sampleRate].any? {|rate| rate == "#{@sampleRate}".to_i} == true &&
      @encodevals[:sampleEnc].any?  {|enc| enc == "#{@sampleEnc}".to_i}    == true &&
      @encodevals[:sampleDep].any?  {|dep| dep == "#{@sampleDep}".to_i}    == true &&
      @encodevals[:channels].any?   {|chan| chan == "#{@channels}".to_i}   == true
    # Audio dynamics evaluation
    if "#{@flat}".to_f  < @levelvals[:flat]
      @file_score   += 10
    else
      @issues.push("flat")
    end
    if "#{@crest}".to_f > @levelvals[:crest]
      @file_score   += 5
    else
      @issues.push("crest")
    end
    @file_score   += 10 if "#{@peak}".to_f  < @levelvals[:peak]
    @file_score   += 15 if "#{@rms}".to_f   < @levelvals[:rms]
    # Finish up and return json msg
    if @file_score  >= 40
      @validation = true
    else
      @validation = false
    end
    @issues.push("none") if @issues.size == 0
    return {:file => "#{@source}", :pass => @validation,
            :score => @file_score, :enc  => @enc, :stats => @stats,
            :issues => @issues}.to_json
    end
  attr_reader :pass, :flat, :crest, :peak, :rms, :seconds, :issues
end

