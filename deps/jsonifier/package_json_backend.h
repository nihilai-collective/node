#ifndef DEPS_JSONIFIER_PACKAGE_JSON_BACKEND_H_
#define DEPS_JSONIFIER_PACKAGE_JSON_BACKEND_H_

#include <string_view>

#include "node_json_events.h"

namespace node {
namespace modules {

inline constexpr std::string_view kJsonifierUtf8Bom = "\xEF\xBB\xBF";

struct PackageJSONSpans {
  std::string_view name;
  std::string_view main;
  std::string_view type;
  std::string_view exports;
  std::string_view imports;
  std::string_view scripts;
  bool has_name = false;
  bool has_main = false;
  bool has_exports = false;
  bool has_imports = false;
  bool has_scripts = false;
  bool has_private = false;
  bool is_private = false;
};

class PackageJSONBackendParser {
 public:
  virtual ~PackageJSONBackendParser();
  virtual bool Parse(std::string_view json, PackageJSONSpans* spans) = 0;
};

namespace isa_avx512 {
PackageJSONBackendParser* NewGenericParser();
std::string_view WalkJson(std::string_view json, json::JsonEventSink* sink);
}  // namespace isa_avx512

namespace isa_avx2 {
PackageJSONBackendParser* NewGenericParser();
std::string_view WalkJson(std::string_view json, json::JsonEventSink* sink);
}  // namespace isa_avx2

namespace isa_fallback {
PackageJSONBackendParser* NewGenericParser();
std::string_view WalkJson(std::string_view json, json::JsonEventSink* sink);
}  // namespace isa_fallback

namespace isa_neon {
PackageJSONBackendParser* NewGenericParser();
std::string_view WalkJson(std::string_view json, json::JsonEventSink* sink);
}  // namespace isa_neon

}  // namespace modules
}  // namespace node

#endif  // DEPS_JSONIFIER_PACKAGE_JSON_BACKEND_H_
