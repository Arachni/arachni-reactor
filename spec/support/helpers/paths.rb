def spec_path
    File.expand_path( "#{File.dirname( __FILE__ )}/../.." ) + '/'
end

def support_path
    "#{spec_path}support/"
end

def fixtures_path
    "#{support_path}fixtures/"
end

def pems_path
    "#{fixtures_path}pems/"
end

def support_lib_path
    "#{support_path}lib/"
end

def servers_path
    "#{spec_path}support/servers/"
end
