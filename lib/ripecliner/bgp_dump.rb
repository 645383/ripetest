require "open-uri"
require "csv"
require "json"

module RIPECLINER

  class BGPDump
    attr_writer :file
    attr_accessor :date
    def initialize(date)
      @date = Time.parse date #we could ommmit complex date parsing or call custom method here wich return date
      # set_date e.g
    end

    def set_date
      date = Time.parse date
      # some after processing
      @date = date
    end

    BASE_URL  = "http://data.ris.ripe.net/rrc06"
    DUMPS_URL = File.expand_path("../../dumps", File.dirname(__FILE__)).to_s
    HEADERS   = [:type,
                 :time,
                 :unknown1,
                 :from_ip,
                 :from_asn,
                 :prefix,
                 :aspath,
                 :origin,
                 :next_hop,
                 :unknown2,
                 :multi_exit_disc,
                 :community,
                 :atomic_aggregator,
                 :aggregator]

    def download
      show_progress("downloading") do #this stuff may causes slow down?
        # 9 Mb file downloads few minutes. and much faster without it

        find_dump

        unless File.exist? @file #why to call recursively if this condition will not let you enter
          begin
            File.open(@file, "w") { |gz| IO.copy_stream(open(@url), gz) }
          rescue OpenURI::HTTPError => e
            puts e.message
            previous_date!
            download # try again
          end
        end

      end
    end

    def convert
      show_progress("converting") do # same as in #download

        find_dump

        convert_to_csv
        convert_to_json

      end
    end

    def date=(date)
      digits = date ? date.scan(/\d/)
                    : []
      now    = Time.new.utc

      date =
        case digits.size
        when 8
          Time.utc(digits[0, 4].join, # %Y
                   digits[4, 2].join, # %m
                   digits[6, 2].join, # %d
                   now.hour)
        when 0
          now
        else
          raise ArgumentError.new("Wrong date format! Try: #{now.strftime("%Y.%m.%d")}")
        end

      #can we just Time.parse(date).strftime("%Y%m%d") and not to do all above. Anyway you suppose to get year, month, day format.

      date = now if date > now

      hour =
        case date.hour
        when 0...8   then "0000"
        when 8...16  then "0800"
        when 16...24 then "1600"
        end

      @date = date.strftime("%Y%m%d.#{hour}")
    end

    private

    def find_dump
      use_date_from_file! unless @date

      parent_dir = "/%{year}.%{month}" % { year:  @date[0, 4],
                                           month: @date[4, 2] }
      # is simpler =>> "#{date.year}.#{date.month}"
      dumps_parent_dir = DUMPS_URL + parent_dir
      filename = "/bview.#{@date}.gz"

      unless File.exist? dumps_parent_dir
        FileUtils.mkdir  dumps_parent_dir
      end

      @file = dumps_parent_dir      + filename
      @url  = BASE_URL + parent_dir + filename
    end

    def convert_to_csv
      gz = @file
      download unless File.exist? gz

      @file = "#{@file.split(".")[0...-1].join(".")}.csv" # replace extension to .csv

      unless File.exist? @file
        `bgpdump -t change -m -O #{@file} #{gz}`
      end
    end

    def convert_to_json
      csv_file = @file
      @file = "#{@file.split(".")[0...-1].join(".")}.json" # replace extension to .json

      File.open(@file, "w") do |json|
        json.puts "["

        CSV.open(csv_file, "r") do |csv|
          while row = csv.shift
            hash_row  = Hash[HEADERS.zip row[0].split("|", -1)] #why used CSV here if we need to split the row manually.
            # pass separator param to CSV and you'll get splited
            separator = csv.eof? ? ""
                                 : ","
            json_row  = JSON.pretty_generate(hash_row, indent: "    ").sub!(/^}$/, "  }#{separator}") #no need to gsub
            # each time. just once in the end of parsing
            json.puts "  %s" % json_row
          end
        end

        json.puts "]"
      end
    end

    def use_date_from_file!
      @date = @file.split(".")[2, 2].join(".") # extract date from filename
    end

    def show_progress(message, &block)
      print message

      bar = Thread.new do
        loop do
          print "."
          sleep 0.5
        end
      end

      block.call

      bar.kill
      puts "[ OK ]"
      puts "Dump was successfully saved at #{@file}"
    end

    def previous_date!
      format       = "%Y%m%d.%H00"
      current_date = Time.strptime(@date, format)
      eight_hours  = 8 * 60 * 60
      @date        = (current_date - eight_hours).strftime(format)
    end
  end

end
