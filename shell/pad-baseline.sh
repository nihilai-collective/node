#!/usr/bin/env bash
# shell/pad-baseline.sh <node_dir>

set -e
cd "$1"

perl -0pi -e 's/(int ReadFileSync\(const char\* path, std::string\* result\) \{\n  return ReadFileSyncImpl\(path, \[result\]\(size_t size\) \{\n)    result->resize\(size\);/$1    result->reserve(size + 64);\n    result->resize(size);/' src/node_file_utils.cc
perl -0pi -e 's/package_config\.raw_json = source\.ToString\(\);/package_config.raw_json.reserve(source.length() + simdjson::SIMDJSON_PADDING);\n    package_config.raw_json.assign(*source, source.length());/; s/package_config\.raw_json = std::string\(view\.data\(\), view\.length\(\)\);/package_config.raw_json.reserve(view.length() + simdjson::SIMDJSON_PADDING);\n    package_config.raw_json.assign(view.data(), view.length());/; s/simdjson::pad\(package_config->raw_json\)/simdjson::pad_with_reserve(package_config->raw_json)/' src/node_modules.cc

grep -q 'result->reserve(size + 64);' src/node_file_utils.cc || { echo "pad-baseline: ReadFileSync patch did not apply" >&2; exit 1; }
grep -q 'SIMDJSON_PADDING' src/node_modules.cc || { echo "pad-baseline: binding patch did not apply" >&2; exit 1; }
grep -q 'simdjson::pad(package_config->raw_json)' src/node_modules.cc && { echo "pad-baseline: parse still calls simdjson::pad" >&2; exit 1; }
echo "pad-baseline: applied"
