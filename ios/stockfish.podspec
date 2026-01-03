require 'yaml'

pubspec = YAML.load(File.read(File.join(__dir__, '../pubspec.yaml')))

Pod::Spec.new do |s|
  s.name             = pubspec['name']
  s.version          = pubspec['version']
  s.summary          = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE', :type => 'GPL-3.0' }
  s.author           = 'Arjan Aswal'
  s.source           = { :path => '.' }
  
  # --- THE FIX: Path updates ---
  # We point to 'Classes' for the Swift/Obj-C bridge 
  # and '../src' for the shared C++ engine and FFI bridge.
  s.source_files = 'Classes/**/*', '../src/ffi.cpp', '../src/ffi.h', '../src/stockfish/**/*.{cpp,h}'
  s.public_header_files = 'Classes/**/*.h', '../src/ffi.h'
  
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.ios.deployment_target  = '12.0'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src/stockfish"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }

  s.library = 'c++'

  # Keep your NNUE download logic
  s.script_phase = [
    {
      :execution_position => :before_compile,
      :name => 'Download nnue',
      :script => "cd \"$PODS_TARGET_SRCROOT/../src/stockfish\" && [ -e 'nn-1111cefa1111.nnue' ] || curl --location --remote-name 'https://tests.stockfishchess.org/api/nn/nn-1111cefa1111.nnue'"
    }
  ]

  # Your high-performance compiler flags
  s.xcconfig = {
    'OTHER_CPLUSPLUSFLAGS[config=Debug]' => '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT',
    'OTHER_CPLUSPLUSFLAGS[config=Release]' => '$(inherited) -fno-exceptions -std=c++17 -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -flto=full',
    'OTHER_LDFLAGS[config=Release]' => '$(inherited) -flto=full'
  }
end