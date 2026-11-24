#ifndef DEPS_JSONIFIER_PACKAGE_JSON_GENERIC_PARSER_INL_H_
#define DEPS_JSONIFIER_PACKAGE_JSON_GENERIC_PARSER_INL_H_

namespace node {
namespace modules {
namespace NODE_JSONIFIER_ISA_NS {

static std::string_view ToView(const jsonifier::string_view& value) {
  return {value.data(), static_cast<size_t>(value.size())};
}

class GenericParser final : public PackageJSONBackendParser {
 public:
  bool Parse(std::string_view json, PackageJSONFieldSink* sink) override {
    if (json.starts_with(kJsonifierUtf8Bom)) {
      json.remove_prefix(kJsonifierUtf8Bom.size());
    }

    jsonifier::generic::package_json_fields fields{};
    if (parser_.readPackageJson(json, fields) !=
        jsonifier::generic::error_codes::success) {
      return false;
    }
    if (fields.hasName) {
      sink->SetName(ToView(fields.name));
    }
    if (fields.hasMain) {
      sink->SetMain(ToView(fields.main));
    }
    if (!fields.type.empty()) {
      sink->SetType(ToView(fields.type));
    }
    if (fields.hasExports) {
      sink->SetExports(ToView(fields.exports));
    }
    if (fields.hasImports) {
      sink->SetImports(ToView(fields.imports));
    }
    if (fields.hasScripts) {
      sink->SetScripts(ToView(fields.scripts));
    }
    if (fields.hasPrivate) {
      sink->SetPrivate(fields.isPrivate);
    }
    return true;
  }

 private:
  jsonifier::jsonifier_core parser_;
};

PackageJSONBackendParser* NewGenericParser() {
  return new GenericParser();
}

}  // namespace NODE_JSONIFIER_ISA_NS
}  // namespace modules
}  // namespace node

#endif  // DEPS_JSONIFIER_PACKAGE_JSON_GENERIC_PARSER_INL_H_
