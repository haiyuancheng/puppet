require 'puppet'
require 'puppet/application'
require 'puppet/ssl/certificate_authority'

Puppet::Application.new(:puppetca) do

    should_parse_config

    attr_accessor :cert_mode, :all, :signed, :ca

    def find_mode(opt)
        modes = Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS
        tmp = opt.sub("--", '').to_sym
        @cert_mode = modes.include?(tmp) ? tmp : nil
    end

    option("--clean", "-c") do
        @cert_mode = :destroy
    end

    option("--all", "-a") do
        @all = true
    end

    option("--signed", "-s") do
        @signed = true
    end

    option("--debug", "-d") do |arg|
        Puppet::Util::Log.level = :debug
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject {|m| m == :destroy }.each do |method|
        option("--#{method}", "-%s" % method.to_s[0,1] ) do
            find_mode("--#{method}")
        end
    end

    option("--[no-]allow-dns-alt-names") do |value|
        options[:allow_dns_alt_names] = value
    end

    option("--verbose", "-v") do
        Puppet::Util::Log.level = :info
    end

    command(:main) do
        if @all
            hosts = :all
        elsif @signed
            hosts = :signed
        else
            hosts = ARGV.collect { |h| puts h; h.downcase }
        end

        # If we are generating, and the option came from the CLI, it gets added to
        # the data.  This will do the right thing for non-local certificates, in
        # that the command line but *NOT* the config file option will apply.
        if @cert_mode == :generate
            if Puppet.settings.setting(:dns_alt_names).setbycli
                options[:dns_alt_names] = Puppet[:dns_alt_names]
            end
        end

        begin
            @ca.apply(@cert_mode, options.merge(:to => hosts))
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            puts detail.to_s
            exit(24)
        end
    end

    setup do
        if Puppet.settings.print_configs?
            exit(Puppet.settings.print_configs ? 0 : 1)
        end

        Puppet::Util::Log.newdestination :console

        if [:generate, :destroy].include? @cert_mode
            Puppet::SSL::Host.ca_location = :local
        else
            Puppet::SSL::Host.ca_location = :only
        end

        begin
            @ca = Puppet::SSL::CertificateAuthority.new
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            puts detail.to_s
            exit(23)
        end
    end
end
