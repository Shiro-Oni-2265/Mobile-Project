# Hướng dẫn kiểm thử và bằng chứng

## Quy tắc ghi kết quả

Chỉ đánh dấu đạt sau khi thực sự chạy. Ghi ngày, commit, công cụ/thiết bị, bước thao tác, kết quả thực tế và đường dẫn log/ảnh. Một test tự động dùng mock không chứng minh app chạy trên Android. Wireframe và danh sách kiểm tra không phải ảnh/log chạy thật.

## Môi trường và lệnh

Flutter stable **3.47.7** là SDK được chọn cho lần chuyển đổi; Node.js >=20, json-server 0.17.4. Android SDK/emulator hoặc máy thật cần được cài riêng. Trong app, các lệnh tương đương:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --flavor demo --release --dart-define-from-file=config/dev.example.json
flutter run --flavor demo --dart-define-from-file=config/dev.example.json
```

Có thể dùng app/tool/naugi.ps1 với -Action analyze, test, build, run hoặc integration. -ConfigPath mặc định chọn config/dev.json nếu có, nếu không chọn config/dev.example.json; -DeviceId dùng để chọn máy.

Trong backend:

```powershell
npm ci
npm run lint
npm test
npm start
```

Tích hợp Android dùng flutter test integration_test --flavor demo --dart-define-from-file=config/dev.example.json -d ID_THIET_BI hoặc helper -Action integration -DeviceId ID_THIET_BI. Xác nhận backend đã chạy trước khi kiểm thử luồng mạng. Không chạy reset trên runtime chứa dữ liệu cần giữ.

## Bằng chứng tự động

| Kiểm tra | Kết quả đã biết | Giới hạn |
|---|---|---|
| Backend npm ci | Đã chạy; audit 0 theo lần cài của phiên chuyển đổi | Không chứng minh an toàn mọi tình huống |
| Backend npm run lint | Đã chạy đạt | Kiểm tra cú pháp script |
| Backend npm test | Đã chạy 3/3 đạt | Seed/tham chiếu, init giữ runtime, HTTP thật trên cổng ngẫu nhiên với GET/POST/PUT/DELETE và lưu bền |
| Export seed từ catalog nguồn | Đã chạy tạo 20 công thức, 25 nguyên liệu; kiểm tra --check đạt | Dữ liệu minh họa, không xác nhận tính đúng dinh dưỡng |
| Docker compose config | Đã kiểm tra cấu hình hợp lệ | Chưa chạy container vì daemon không sẵn sàng |
| Flutter analyze/test | Đã chạy đạt, chi tiết ngay dưới bảng | Chưa chứng minh APK hoặc UI trên Android |
| Flutter build APK | Đang kiểm tra trong lần chuyển đổi | Chỉ ghi đạt khi lệnh kết thúc và có APK thực |
| Integration Android | Chưa xác minh trong bảng này | Cần thiết bị/emulator và backend thật |

### Kết quả chạy ngày 19/10/2026 trong workspace chuyển đổi

| Lệnh / phép kiểm | Kết quả quan sát | Giới hạn |
|---|---|---|
| `flutter analyze` trong `app/` | Đạt, `No issues found` | Phân tích tĩnh, không xác nhận thiết bị |
| `flutter test --concurrency=1` trong `app/` | Đạt 62/62 bài kiểm tra | Phần lớn dùng API giả; bài `rest_contract_test.dart` khởi động json-server thật trên cổng ngẫu nhiên với SQLite thật |
| `npm test --prefix backend` | Đạt 3/3, gồm CRUD HTTP thật trên dữ liệu thử độc lập | Không tác động `backend/runtime/db.json` của người dùng |
| `flutter test --dart-define=CAPTURE_SCREENSHOTS=true test/guest_widget_test.dart` | Đạt 2/2; tạo [Hôm nay](asset/naugi-home-widget.png) và [chi tiết](asset/naugi-recipe-widget.png) | Ảnh render của Flutter widget test với API giả, chưa phải ảnh Android |
| Bản clone sạch từ snapshot các file sẽ được nộp | `npm ci`, backend lint/test 3/3, `flutter pub get`, `flutter analyze`, Flutter test 62/62 đều đạt | Snapshot kiểm tra ở `.tools/clean-verification/clone`, không gồm SDK; APK và chạy Android cần ghi riêng |

Bài `integration_test/guest_flow_test.dart` dùng SQLite thật nhưng API giả trong cùng tiến trình. Bài `test/rest_contract_test.dart` dùng HTTP qua json-server thật và SQLite thật. Kiểm tra Android chạy app với API thật vẫn cần thực hiện trên emulator hoặc máy thật trước khi đánh dấu các hàng M01–M22 là đạt.

Lần build APK đầu trên Flutter 3.47.7 dừng ở `compileDemoReleaseJavaWithJavac`: Java registrant tạo sẵn tham chiếu plugin `integration_test`, trong khi Gradle loại plugin ở chế độ release do nó thuộc `dev_dependencies`. `app/pubspec.yaml` đã chuyển plugin này thành dependency thường để khớp registrant với Gradle; kết quả build lại sẽ ghi riêng sau khi lệnh kết thúc. Không dùng lần build lỗi làm bằng chứng APK.

Số liệu ở trên chỉ nói về lần thực thi được người thực hiện báo lại trong phiên chuyển đổi, không áp dụng cho mã thay đổi về sau. Trước nộp bài cần bổ sung log tái lập gắn commit cuối.

## Kịch bản thủ công — chưa xác minh

Tất cả hàng dưới đang **chưa chạy/ghi bằng chứng** trong tài liệu này. Sau khi chạy, thay cột trạng thái bằng kết quả thật và thêm tên file minh chứng.

| ID | Chuẩn bị / thao tác | Kết quả mong đợi | Trạng thái |
|---|---|---|---|
| M01 | Cài app mới, API chạy, mở Công thức | loading rồi dữ liệu từ REST; GET có thể quan sát ở backend | Chưa xác minh |
| M02 | Tải xong, bật airplane mode, mở lại app | Đọc cache, cảnh báo refresh lỗi, retry khả dụng | Chưa xác minh |
| M03 | App mới chưa cache, API tắt | Hiện error/retry; không tự hiện seed như thành công | Chưa xác minh |
| M04 | Tắt mạng, sửa thực đơn/tủ lạnh/mua sắm/tùy chọn/yêu thích | Dữ liệu lưu local; force-stop rồi mở lại vẫn còn | Chưa xác minh |
| M05 | Tạo công thức online | POST thành công, ID UUID; refresh/mở lại có món | Chưa xác minh |
| M06 | Sửa/xóa món thường | PUT/DELETE cập nhật danh mục; bữa dùng bản chụp vẫn đọc được | Chưa xác minh |
| M07 | Mở món sample, sao chép | Không sửa/xóa mẫu; bản sao có ID mới, sample=false | Chưa xác minh |
| M08 | Tạo/sửa khi API không chạy | Lỗi, nội dung form giữ; không báo đã lưu | Chưa xác minh |
| M09 | Làm chậm API quá 15 giây | Timeout, có cảnh báo; không tự lặp POST; kiểm tra ID trước retry | Chưa xác minh |
| M10 | API trả HTTP lỗi hoặc JSON hỏng | Error rõ; cache trước còn nguyên | Chưa xác minh |
| M11 | Chạy API thử có recipes=[] và ingredients=[] | empty, hướng dẫn thêm; không hồi sinh cache/seed cũ | Chưa xác minh |
| M12 | Tìm tên không có hoặc lọc không có kết quả | Empty có cách bỏ lọc; không xem là lỗi mạng | Chưa xác minh |
| M13 | Thêm món 2 phần vào bữa 4 người | Lượng mua/dinh dưỡng nhân 2; không đổi món gốc | Chưa xác minh |
| M14 | Tủ lạnh có kg/g, l/ml, lô hết hạn, lượng “vừa đủ” | Chuẩn hóa đúng; không đổi ml sang g; không trừ lô hết hạn | Chưa xác minh |
| M15 | Tạo nguyên liệu thiếu dinh dưỡng/khối lượng mỗi cái | Kết quả báo chưa đầy đủ; không tự coi là 0 chính xác | Chưa xác minh |
| M16 | Chọn ảnh trên máy A, refresh từ máy B | Máy A còn ảnh local; không gửi đường dẫn ảnh lên REST | Chưa xác minh |
| M17 | Thu hồi quyền ảnh/thông báo, thử lại | Thông báo phù hợp, không crash; app vẫn dùng chức năng khác | Chưa xác minh |
| M18 | Xoay màn hình khi nhập form; tăng font và đổi cỡ cửa sổ | Ghi nhận thực tế dữ liệu nhập/overflow; sửa nếu có | Chưa xác minh |
| M19 | Máy nhỏ và lớn, bàn phím mở, TalkBack | Nút truy cập được, nhãn có nghĩa, không bị che | Chưa xác minh |
| M20 | Nâng cấp fixture guest v1, nhập có xác nhận hai lần | Có backup; không tự upload; nhập theo ID không nhân đôi; dữ liệu account không bị tự nhập | Chưa xác minh |
| M21 | Máy thật nối cùng LAN, config đúng, demo release | HTTP hoạt động theo cấu hình; không phụ thuộc localhost thiết bị | Chưa xác minh |
| M22 | Clone sạch, cài theo README, chạy build | Không cần file bí mật hoặc artifact ngoài hướng dẫn | Chưa xác minh |

Khi kiểm tra timeout/lỗi/empty, dùng backend thử riêng và ghi cách gây lỗi. Không sửa seed chính rồi quên khôi phục. Khi chụp bằng chứng, không đưa thông tin cá nhân hoặc đường dẫn nhạy cảm vào ảnh.

## Mẫu biên bản

- Ngày / commit:
- Người thực hiện (sinh viên tự điền):
- Thiết bị, Android, kích thước / SDK:
- Kịch bản và dữ liệu đầu vào:
- Lệnh hoặc thao tác:
- Kết quả thực tế, đạt/chưa đạt:
- Log/ảnh thật trong docs/asset/:
- Vấn đề còn lại và cách tái hiện:

Không tuyên bố giữ form khi xoay, hỗ trợ mọi thiết bị hoặc nhắc hạn chính xác trước khi có kết quả tương ứng.
