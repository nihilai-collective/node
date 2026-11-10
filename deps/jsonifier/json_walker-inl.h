#ifndef DEPS_JSONIFIER_JSON_WALKER_INL_H_
#define DEPS_JSONIFIER_JSON_WALKER_INL_H_

namespace node {
namespace modules {
namespace NODE_JSONIFIER_ISA_NS {

class JsonWalker {
 public:
  static bool Walk(const jsonifier::generic::value& value,
                   json::JsonEventSink* sink,
                   size_t depth) {
    if (depth > kMaxDepth) {
      return false;
    }
    switch (value.type()) {
      case jsonifier::json_type::object:
        return WalkObject(value, sink, depth);
      case jsonifier::json_type::array:
        return WalkArray(value, sink, depth);
      case jsonifier::json_type::string: {
        std::string_view text;
        if (value.getString(text) != kSuccess) {
          return false;
        }
        sink->String(text);
        return true;
      }
      case jsonifier::json_type::number: {
        jsonifier::string_view raw{};
        double parsed;
        if (value.rawJson(raw) != kSuccess ||
            value.getDouble(parsed) != kSuccess) {
          return false;
        }
        sink->Number(ToView(raw), parsed);
        return true;
      }
      case jsonifier::json_type::boolean: {
        bool parsed;
        if (value.getBool(parsed) != kSuccess) {
          return false;
        }
        sink->Bool(parsed);
        return true;
      }
      case jsonifier::json_type::null:
        if (!value.isNull()) {
          return false;
        }
        sink->Null();
        return true;
      default:
        return false;
    }
  }

 private:
  static constexpr size_t kMaxDepth = 1024;
  static constexpr jsonifier::generic::error_code kSuccess =
      jsonifier::generic::error_code::success;

  static bool WalkObject(const jsonifier::generic::value& value,
                         json::JsonEventSink* sink,
                         size_t depth) {
    jsonifier::generic::object object = value.getObject();
    if (object.error() != kSuccess) {
      return false;
    }
    sink->StartObject();
    for (jsonifier::generic::field field : object) {
      std::string_view key;
      if (field.error() != kSuccess || field.unescapedKey(key) != kSuccess) {
        return false;
      }
      sink->Key(key);
      if (!Walk(field.value(), sink, depth + 1)) {
        return false;
      }
    }
    sink->EndObject();
    return true;
  }

  static bool WalkArray(const jsonifier::generic::value& value,
                        json::JsonEventSink* sink,
                        size_t depth) {
    jsonifier::generic::array array = value.getArray();
    if (array.error() != kSuccess) {
      return false;
    }
    sink->StartArray();
    for (jsonifier::generic::value element : array) {
      if (element.error() != kSuccess || !Walk(element, sink, depth + 1)) {
        return false;
      }
    }
    sink->EndArray();
    return true;
  }
};

bool WalkJson(std::string_view json, json::JsonEventSink* sink) {
  if (json.starts_with(kJsonifierUtf8Bom)) {
    json.remove_prefix(kJsonifierUtf8Bom.size());
  }
  jsonifier::jsonifier_core parser;
  jsonifier::generic::document document = parser.iterate(json);
  if (document.error() != jsonifier::generic::error_code::success) {
    return false;
  }
  return JsonWalker::Walk(document, sink, 0);
}

}  // namespace NODE_JSONIFIER_ISA_NS
}  // namespace modules
}  // namespace node

#endif  // DEPS_JSONIFIER_JSON_WALKER_INL_H_
