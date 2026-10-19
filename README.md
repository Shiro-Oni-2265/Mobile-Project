# NauGi — Nấu gì?

Ứng dụng Android cho sổ tay công thức, lên thực đơn, tủ lạnh, mua sắm và dinh dưỡng.
Bài tập lớn Lập trình ứng dụng thiết bị di động — Phạm Trường Giang, Trần Sỹ Tiến.

## Chạy ngay bằng chế độ khách

Yêu cầu: Flutter **3.47.7 stable** (Dart 3.13.5), Android Studio/SDK, JDK 21 hoặc JDK tương thích Gradle 9.3.1,
máy ảo hoặc điện thoại Android 7.0/API 24 trở lên. SDK build dùng compile/target API 36;
Gradle có thể tải API/NDK còn thiếu sau khi chấp nhận giấy phép.

```powershell
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter run
```

Chọn **Tiếp tục với tư cách khách**. Không cần Supabase hoặc Gemini để sử dụng các chức năng cục bộ.
Máy trong phiên phát triển này có Flutter ở `.tools/flutter/bin`, Android SDK ở `D:/Android/SDK`.
SDK cục bộ không được đưa vào Git; máy khác nên cài Flutter riêng và đưa `bin` vào PATH.

Trên Windows có thể dùng script tự tìm Flutter và thiết lập môi trường tạm trong tiến trình:

```powershell
.\tool\naugi.ps1 -Action run
.\tool\naugi.ps1 -Action test
.\tool\naugi.ps1 -Action build
# Sau khi cấu hình dịch vụ:
.\tool\naugi.ps1 -Action run -Cloud
```

## Chức năng

- 20 món Việt mẫu; sao chép vào sổ tay, thêm/sửa/xóa món, ảnh từ thư viện, tìm kiếm, danh mục, yêu thích.
- Khẩu phần linh hoạt, nguyên liệu có lượng hoặc “vừa đủ”, từng bước có thể đánh dấu khi nấu.
- Lịch tuần sáng/trưa/tối; thay món, chuyển ngày/bữa, sửa khẩu phần; giữ công thức chụp tại lúc thêm.
- Danh sách mua từ khoảng ngày; gộp g–kg, ml–l; xem trước và xác nhận đối chiếu tủ lạnh.
- Tủ lạnh theo lô và hạn sử dụng, nhắc lúc khoảng 8 giờ trước hạn 2 ngày và ngày hết hạn.
- Kcal/protein/carb/chất béo cho cả món, mỗi khẩu phần, từng bữa và ngày. Tổng ngày là tổng **tất cả khẩu phần đã xếp**.
- Danh mục dinh dưỡng tham chiếu nhỏ, có thể thêm/sửa dữ liệu và nguồn. Nguyên liệu thiếu dữ liệu được đánh dấu;
  không quy đổi ml sang g và không giả định phần thiếu bằng 0. Xem [nguồn dữ liệu](assets/data/README.md).
- Gợi ý theo nguyên liệu, hạn dùng, thời gian và sở thích chạy độc lập trên thiết bị.
- AI chỉ chọn món từ thư viện, yêu cầu đăng nhập và cấu hình máy chủ. AI lỗi hiển thị không khả dụng,
  không tự tạo kết quả thay thế. Các gợi ý độc lập và chức năng khác vẫn dùng được.
- Khách lưu SQLite và chỉnh sửa offline. Tài khoản đồng bộ Supabase, cache chỉ đọc khi không tải được máy chủ.
- Chuyển dữ liệu khách vào tài khoản sau xác nhận; giữ dữ liệu cũ, chống nhập trùng theo ID và chỉ xóa bản khách sau khi máy chủ xác nhận.

## Bật tài khoản, đồng bộ và AI

Theo hướng dẫn [thiết lập dịch vụ](docs/SETUP.md). Sau khi cấu hình:

```powershell
Copy-Item config/dev.example.json config/dev.json
# Điền SUPABASE_URL và SUPABASE_ANON_KEY trong config/dev.json.
flutter run --dart-define-from-file=config/dev.json
```

`SUPABASE_ANON_KEY` nhận publishable key hoặc legacy anon key. Đây là khóa công khai của ứng dụng;
quyền dữ liệu được bảo vệ bằng RLS. Không đưa service-role key hoặc Gemini key vào ứng dụng.
Các file cấu hình thật và khóa ký được bỏ qua bởi Git.

## Kiểm thử và APK

```powershell
flutter analyze
flutter test
flutter test integration_test/guest_flow_test.dart -d <device-id>
deno check supabase/functions/suggest-recipes/index.ts
deno test supabase/functions/suggest-recipes/logic_test.ts
flutter build apk --release
# Nếu cần dịch vụ tài khoản, thêm --dart-define-from-file=config/dev.json vào lệnh build.
```

APK ở `build/app/outputs/flutter-apk/app-release.apk`. Bản đồ án dùng khóa ký debug của máy build;
không bật thu gọn R8 và không phải cấu hình phát hành Google Play. Giữ cùng khóa nếu muốn cài đè mà không mất dữ liệu.
CI GitHub Actions chạy analyze, unit/widget tests, kiểm tra Edge Function và tạo APK chế độ khách.

Nếu Windows/JDK báo `Unable to establish loopback connection` với thư mục tạm quá dài:

```powershell
New-Item -ItemType Directory -Force .tools/tmp | Out-Null
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=' + (Resolve-Path .tools/tmp).Path
flutter build apk --release
```

Không thay đổi TEMP của toàn hệ thống. Nếu đường dẫn dự án rất dài, đặt thư mục tạm ở vị trí ngắn mà bạn có quyền ghi.
Kotlin incremental cache được tắt trong dự án để tránh lỗi Pub cache trên C: trong khi mã nguồn trên D:.

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `lib/domain` | Mô hình, tính dinh dưỡng, mua sắm, gợi ý và ghép dữ liệu |
| `lib/data` | SQLite, Supabase, dữ liệu mẫu |
| `lib/services` | Nhắc hạn và ảnh cá nhân |
| `lib/ui` | Màn hình tiếng Việt |
| `supabase` | Migration, seed, Edge Function, SQL kiểm thử quyền |
| `test`, `integration_test` | Kiểm thử tự động và Android/SQLite |
| `docs` | Thiết lập, kiến trúc, kế hoạch và nghiệm thu |

Xem [kiến trúc](docs/ARCHITECTURE.md), [kế hoạch](docs/PLAN.md), [kiểm thử và demo](docs/TESTING.md).

Đăng nhập Google/email, gửi email, gọi Gemini và RLS trên dịch vụ thật phải được nghiệm thu sau khi cấu hình dự án của nhóm.
Miễn phí là trong hạn mức nhà cung cấp, không phải cam kết khả dụng vô hạn. Ứng dụng không tự bật gói trả phí.

