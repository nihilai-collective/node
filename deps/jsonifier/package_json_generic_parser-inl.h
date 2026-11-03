namespace node {
namespace modules {
namespace NODE_JSONIFIER_ISA_NS {
namespace {

using SinkSetter = void (PackageJSONFieldSink::*)(std::string_view);

std::string_view ToView(const jsonifier::string_view& value) {
  return {value.data(), value.size()};
}

std::string_view ToView(const jsonifier::string& value) {
  return {value.data(), value.size()};
}

enum class PackageField {
  kOther,
  kName,
  kMain,
  kType,
  kExports,
  kImports,
  kPrivate,
  kScripts,
};

PackageField ClassifyKey(std::string_view key) {
  if (key.size() == 4) {
    switch (key[0]) {
      case 'n':
        return key == "name" ? PackageField::kName : PackageField::kOther;
      case 'm':
        return key == "main" ? PackageField::kMain : PackageField::kOther;
      case 't':
        return key == "type" ? PackageField::kType : PackageField::kOther;
      default:
        return PackageField::kOther;
    }
  }
  if (key.size() == 7) {
    switch (key[0]) {
      case 'e':
        return key == "exports" ? PackageField::kExports : PackageField::kOther;
      case 'i':
        return key == "imports" ? PackageField::kImports : PackageField::kOther;
      case 'p':
        return key == "private" ? PackageField::kPrivate : PackageField::kOther;
      case 's':
        return key == "scripts" ? PackageField::kScripts : PackageField::kOther;
      default:
        return PackageField::kOther;
    }
  }
  return PackageField::kOther;
}

}  // namespace

class GenericParser final : public PackageJSONBackendParser {
 public:
  bool Parse(std::string_view json, PackageJSONFieldSink* sink) override {
    if (json.starts_with(kJsonifierUtf8Bom)) {
      json.remove_prefix(kJsonifierUtf8Bom.size());
    }

    jsonifier::generic::document document = parser_.iterate(json);
    if (document.error() != jsonifier::generic::error_code::success) {
      return false;
    }
    jsonifier::generic::object main_object = document.getObject();
    if (main_object.error() != jsonifier::generic::error_code::success) {
      return false;
    }

    for (jsonifier::generic::field field : main_object) {
      if (field.error() != jsonifier::generic::error_code::success) {
        return false;
      }
      const PackageField kind = ClassifyKey(ToView(field.rawKey()));
      if (kind == PackageField::kOther) {
        continue;
      }
      jsonifier::generic::value value = field.value();

      switch (kind) {
        case PackageField::kName:
          if (value.getString(scratch_) !=
              jsonifier::generic::error_code::success) {
            return false;
          }
          sink->SetName(ToView(scratch_));
          break;
        case PackageField::kMain:
          if (value.getString(scratch_) ==
              jsonifier::generic::error_code::success) {
            sink->SetMain(ToView(scratch_));
          }
          break;
        case PackageField::kExports:
          if (!ForwardContainerOrString(value, sink,
                                        &PackageJSONFieldSink::SetExports)) {
            return false;
          }
          break;
        case PackageField::kImports:
          if (!ForwardContainerOrString(value, sink,
                                        &PackageJSONFieldSink::SetImports)) {
            return false;
          }
          break;
        case PackageField::kType: {
          std::string_view type;
          if (value.getString(type) != jsonifier::generic::error_code::success) {
            return false;
          }
          if (type == "commonjs" || type == "module") {
            sink->SetType(type);
          }
          break;
        }
        case PackageField::kPrivate: {
          bool is_private;
          if (value.getBool(is_private) ==
              jsonifier::generic::error_code::success) {
            sink->SetPrivate(is_private);
          }
          break;
        }
        case PackageField::kScripts:
          if (value.type() == jsonifier::json_type::object) {
            jsonifier::string_view raw{};
            if (value.rawJson(raw) != jsonifier::generic::error_code::success) {
              return false;
            }
            sink->SetScripts(ToView(raw));
          }
          break;
        case PackageField::kOther:
          break;
      }
    }
    return true;
  }

 private:
  bool ForwardContainerOrString(const jsonifier::generic::value& value,
                                PackageJSONFieldSink* sink,
                                SinkSetter setter) {
    switch (value.type()) {
      case jsonifier::json_type::object:
      case jsonifier::json_type::array: {
        jsonifier::string_view raw{};
        if (value.rawJson(raw) != jsonifier::generic::error_code::success) {
          return false;
        }
        (sink->*setter)(ToView(raw));
        return true;
      }
      case jsonifier::json_type::string:
        if (value.getString(scratch_) !=
            jsonifier::generic::error_code::success) {
          return false;
        }
        (sink->*setter)(ToView(scratch_));
        return true;
      default:
        return true;
    }
  }

  jsonifier::jsonifier_core parser_;
  jsonifier::string scratch_;
};

PackageJSONBackendParser* NewGenericParser() {
  return new GenericParser();
}

}  // namespace NODE_JSONIFIER_ISA_NS
}  // namespace modules
}  // namespace node
