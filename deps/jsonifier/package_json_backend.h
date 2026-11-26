#ifndef DEPS_JSONIFIER_PACKAGE_JSON_BACKEND_H_
#define DEPS_JSONIFIER_PACKAGE_JSON_BACKEND_H_

#if defined(__GNUC__) && !defined(__clang__)
#define NODE_JSONIFIER_ADAPTER_SPANS 1
#endif

#include <string_view>

#include "node_json_events.h"

namespace node {
namespace modules {

#ifndef NODE_JSONIFIER_ADAPTER_SPANS
struct PackageJSONFields;

#endif /* ! NODE_JSONIFIER_ADAPTER_SPANS */
inline constexpr std::string_view kJsonifierUtf8Bom = "\xEF\xBB\xBF";

#ifndef NODE_JSONIFIER_ADAPTER_SPANS
class PackageJSONFieldSink {
 public:
  explicit PackageJSONFieldSink(PackageJSONFields* fields) : fields_(fields) {}

  void SetName(std::string_view value);
  void SetMain(std::string_view value);
  void SetType(std::string_view value);
  void SetExports(std::string_view value);
  void SetImports(std::string_view value);
  void SetScripts(std::string_view value);
  void SetPrivate(bool value);

 private:
  PackageJSONFields* fields_;
#else /* NODE_JSONIFIER_ADAPTER_SPANS */
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
#endif /* NODE_JSONIFIER_ADAPTER_SPANS */
};

class PackageJSONBackendParser {
 public:
  virtual ~PackageJSONBackendParser();
#ifndef NODE_JSONIFIER_ADAPTER_SPANS
  virtual bool Parse(std::string_view json, PackageJSONFieldSink* sink) = 0;
#else /* NODE_JSONIFIER_ADAPTER_SPANS */
  virtual bool Parse(std::string_view json, PackageJSONSpans* spans) = 0;
#endif /* NODE_JSONIFIER_ADAPTER_SPANS */
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
