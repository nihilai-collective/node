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
  bool Parse(std::string_view json, PackageJSONSpans* spans) override {
    if (json.starts_with(kJsonifierUtf8Bom)) {
      json.remove_prefix(kJsonifierUtf8Bom.size());
    }

    jsonifier::generic::package_json_fields fields{};
    if (parser_.readPackageJson(json, fields) !=
        jsonifier::generic::error_codes::success) {
      return false;
    }
    spans->name = ToView(fields.name);
    spans->main = ToView(fields.main);
    spans->type = ToView(fields.type);
    spans->exports = ToView(fields.exports);
    spans->imports = ToView(fields.imports);
    spans->scripts = ToView(fields.scripts);
    spans->has_name = fields.hasName;
    spans->has_main = fields.hasMain;
    spans->has_exports = fields.hasExports;
    spans->has_imports = fields.hasImports;
    spans->has_scripts = fields.hasScripts;
    spans->has_private = fields.hasPrivate;
    spans->is_private = fields.isPrivate;
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
