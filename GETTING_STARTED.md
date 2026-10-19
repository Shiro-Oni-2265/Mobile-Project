# Chạy NauGi từ bản clone sạch

Yêu cầu chấm điểm nằm trong [INSTRUCTION.md](INSTRUCTION.md); mô tả dự án, cấu hình và lệnh chạy đầy đủ nằm trong [README.md](README.md). Dự án Flutter đã có trong `app/`. Không chạy `flutter create` để ghi đè mã.

## 1. Công cụ

- Git, Node.js 22 và npm để chạy json-server 0.17.4.
- Flutter 3.47.7, Dart 3.13.5, JDK 21, Android SDK (Android là nền tảng nghiệm thu chính).
- Android emulator hoặc thiết bị Android. Docker Desktop là lựa chọn khác để chạy backend.

## 2. Chạy API

Trong PowerShell tại gốc repo:

```powershell
npm ci --prefix backend
.\scripts\api.ps1 -Action start
```

Lệnh khởi tạo `backend/runtime/db.json` từ `backend/seed.json` khi chưa có dữ liệu runtime và phục vụ API tại cổng 3000. Dữ liệu đã chỉnh sửa được giữ khi khởi động lại. Để cố ý đưa dữ liệu về seed:

```powershell
.\scripts\api.ps1 -Action reset
```

Có thể dùng Docker Compose theo [backend/README.md](backend/README.md). Nếu cổng 3000 đã bị chiếm, giải phóng cổng trước khi chạy; script không dừng tiến trình khác.

## 3. Chạy ứng dụng

```powershell
cd app
flutter pub get
flutter run --flavor demo --dart-define-from-file=config/dev.example.json
```

`config/dev.example.json` trỏ Android emulator tới `http://10.0.2.2:3000`. iOS simulator dùng `config/ios.example.json` và cần máy macOS để xác minh. Thiết bị thật dùng địa chỉ LAN của máy chạy API trong cấu hình riêng; xem [README.md](README.md) và [docs/api-integration.md](docs/api-integration.md).

## 4. Kiểm tra và build

```powershell
cd app
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --concurrency=1
flutter build apk --flavor demo --dart-define-from-file=config/dev.example.json
```

Bài kiểm tra REST thật cần `npm ci --prefix backend` trước khi chạy `flutter test`. Kết quả và các bước kiểm tra thủ công được ghi ở [docs/testing-guide.md](docs/testing-guide.md). APK demo dùng cấu hình Android emulator; cần thay URL bằng IP LAN nếu cài trên máy thật.

## 5. Nhóm và nhật ký AI

Nhóm tự xác nhận phần đóng góp trong README. Ghi các buổi dùng AI vào [docs/ai-log.md](docs/ai-log.md), ghi rõ phần nào nhóm giữ lại và tự kiểm chứng. Các điểm cần hiểu để bảo vệ nằm trong [docs/oral-defense.md](docs/oral-defense.md).
