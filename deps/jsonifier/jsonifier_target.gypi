{
  'type': 'static_library',
  'include_dirs': [
    '<(jsonifier_include_dir)',
    '../../src',
  ],
  'cflags_cc!': [ '-fno-exceptions', '-fno-rtti', '-std=gnu++20' ],
  'cflags_cc': [ '-fexceptions', '-frtti', '-std=gnu++23' ],
  'defines!': [ '_HAS_EXCEPTIONS=0' ],
  'xcode_settings': {
    'CLANG_CXX_LANGUAGE_STANDARD': 'gnu++23',
    'GCC_ENABLE_CPP_EXCEPTIONS': 'YES',
    'GCC_ENABLE_CPP_RTTI': 'YES',
  },
  'msvs_settings': {
    'VCCLCompilerTool': {
      'LanguageStandard': 'stdcpplatest',
      'ExceptionHandling': 1,
      'RuntimeTypeInfo': 'true',
    },
  },
  'configurations': {
    'Release': {
      'defines': [ 'NDEBUG' ],
    },
  },
}
