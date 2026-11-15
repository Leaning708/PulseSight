#include "system_font_list.h"

#include <windows.h>
#include <dwrite.h>
#include <wrl/client.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <set>
#include <stdexcept>
#include <string.h>
#include <string>
#include <vector>

namespace {

using Microsoft::WRL::ComPtr;

// 宽字符串大小写不敏感比较器,用于族名去重(不同 region 记录可能重复)。
struct CaseInsensitiveLess {
  bool operator()(const std::wstring& lhs, const std::wstring& rhs) const {
    return _wcsicmp(lhs.c_str(), rhs.c_str()) < 0;
  }
};

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                       static_cast<int>(wide.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string utf8(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                      utf8.data(), size, nullptr, nullptr);
  return utf8;
}

// 枚举 DirectWrite 系统字体族显示名。失败时抛出异常,由通道层转 Error。
std::vector<std::string> ListSystemFontFamilies() {
  ComPtr<IDWriteFactory> factory;
  if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED,
                                 __uuidof(IDWriteFactory),
                                 reinterpret_cast<IUnknown**>(
                                     factory.GetAddressOf())))) {
    throw std::runtime_error("DWriteCreateFactory failed");
  }

  ComPtr<IDWriteFontCollection> collection;
  if (FAILED(factory->GetSystemFontCollection(collection.GetAddressOf(),
                                              FALSE))) {
    throw std::runtime_error("GetSystemFontCollection failed");
  }

  std::set<std::wstring, CaseInsensitiveLess> unique;
  const UINT32 count = collection->GetFontFamilyCount();
  for (UINT32 i = 0; i < count; ++i) {
    ComPtr<IDWriteFontFamily> family;
    if (FAILED(collection->GetFontFamily(i, &family))) {
      continue;
    }
    ComPtr<IDWriteLocalizedStrings> names;
    if (FAILED(family->GetFamilyNames(&names))) {
      continue;
    }

    // 区域名优先级:zh-CN(中文界面显示“微软雅黑”等本地名)→ en-US → 首项。
    UINT32 index = 0;
    BOOL exists = FALSE;
    names->FindLocaleName(L"zh-CN", &index, &exists);
    if (!exists) {
      names->FindLocaleName(L"en-US", &index, &exists);
    }
    if (!exists) {
      index = 0;
    }

    UINT32 length = 0;
    if (FAILED(names->GetStringLength(index, &length))) {
      continue;
    }
    std::wstring name(length + 1, L'\0');
    if (FAILED(names->GetString(index, name.data(), length + 1))) {
      continue;
    }
    name.resize(length);

    // 过滤 "." 前缀隐藏字体,与 macOS 侧行为一致。
    if (!name.empty() && name.front() != L'.') {
      unique.insert(name);
    }
  }

  std::vector<std::string> families;
  families.reserve(unique.size());
  for (const std::wstring& name : unique) {
    families.push_back(WideToUtf8(name));
  }
  return families;
}

}  // namespace

void RegisterSystemFontListChannel(flutter::BinaryMessenger* messenger) {
  // 通道对象须随进程存活,析构会反注册 handler,这里用 static 常驻。
  static const auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "pulsesight/fonts",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name().compare("list") != 0) {
          result->NotImplemented();
          return;
        }
        try {
          flutter::EncodableList families;
          for (std::string& name : ListSystemFontFamilies()) {
            families.emplace_back(std::move(name));
          }
          result->Success(flutter::EncodableValue(std::move(families)));
        } catch (const std::exception& err) {
          result->Error("font_enum_failed", err.what());
        }
      });
}
