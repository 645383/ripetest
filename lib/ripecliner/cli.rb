module RIPECLINER

  class CLI
    attr_reader :dump, :command
    def initialize(params)
      @command  = params[0]
      @dump = RIPECLINER::BGPDump.new params[1]
    end

    def invoke_command
      dump.send command

      #can send command here and not create conditions. it will call command on the BGPDump instance



      case @command
      when "download"
        dump.date = @date
        dump.download
      when "convert"
        dump = RIPECLINER::BGPDump.new

        if @date
          dump.file = @date
        else
          raise ArgumentError.new("Please, specify dump file for converting / downloading.")
        end

        dump.convert
      when "-h", "--help"
        CLI.print_help
      when "-v", "--version"
        puts RIPECLINER::VERSION
      else
        raise ArgumentError.new("Unrecognized command")
      end
    end

    def self.print_help
      puts <<~HELP
        ripecliner is a CLI Downloader & Transformer for RIPE Routing Information Service

          Usage:
            bin/ripecliner -h/--help
            bin/ripecliner -v/--version
            bin/ripecliner command [argument]

          Examples:
            bin/ripecliner download <date>
            bin/ripecliner convert <file>

          Further information:
            https://github.com/defself/ripecliner
      HELP
    end
  end

end
