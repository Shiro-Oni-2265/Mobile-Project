# Kế hoạch chuyển NauGi vào đồ án INT1449

## Phạm vi đã thống nhất

Giữ Flutter, ưu tiên Android, chuyển backend dùng chung sang json-server 0.17.4 cổng 3000. Bỏ auth/Supabase/Google và Gemini trong app hoạt động. Công thức/nguyên liệu đọc và ghi REST; dữ liệu bếp cá nhân lưu SQLite. Ghi công thức chỉ online; không thêm cơ chế đồng bộ ghi offline.

Nguồn tham chiếu được ghi trong [source-provenance.md](source-provenance.md). Không sửa INSTRUCTION.md, không gán công lao cho thành viên và không lấy kết quả kiểm thử nguồn làm kết quả của bản chuyển đổi.

## Các giai đoạn và tiêu chí

| Giai đoạn | Công việc | Tiêu chí kiểm tra |
|---|---|---|
| 1. Nguồn | Lưu commit/URL, nhập app, giữ lịch sử nguồn và ghi nguồn gốc | Có thể đối chiếu file với commit nguồn |
| 2. Backend | Export catalog thành seed, thêm launcher/runtime riêng, khóa phiên bản json-server | GET/POST/PUT/DELETE thật; restart giữ dữ liệu; reset phải chủ động |
| 3. Data layer | RecipeApi + KitchenRepository + LocalStore, URL cấu hình | Widget không gọi HTTP/SQL; cache không giả seed thành công |
| 4. Controller/UI | Bỏ luồng tài khoản, thêm 4 trạng thái và lỗi/retry, sửa CRUD online | View gọi controller, báo kết quả thật, sample chỉ sao chép |
| 5. Dữ liệu cục bộ | Tách yêu thích/ảnh; giữ thực đơn, tủ lạnh, mua sắm, tùy chọn | Offline có thể chỉnh local; payload REST không lộ path ảnh |
| 6. Migration | Backup guest v1, schemaVersion 2 trong scope guest, nhập công thức/nguyên liệu có xác nhận | Không xóa âm thầm, không tự đưa dữ liệu riêng lên server |
| 7. Công cụ | SDK/version, cấu hình mẫu, helper, Android demo flavor, CI | Clone sạch có lệnh tái lập; HTTP demo cấu hình rõ |
| 8. Tài liệu/bảo vệ | Đồng bộ README, kiến trúc, UI, API, kiểm thử, nguồn và AI log | Sinh viên giải thích được mã và tự xác nhận đóng góp |
| 9. Xác minh | Analyze/test/build, backend contract, emulator/thiết bị | Chỉ ghi đạt với log/ảnh chạy thật |

## Bảo toàn dữ liệu cũ

Bản trước có thể lưu Notebook theo scope guest và scope tài khoản. LocalStore nâng phiên bản SQLite lên 2 và sao nguyên payload guest vào scope migration-backup-v1 trong transaction. Repository có bước backup bổ sung nếu cần, rồi ghi Notebook schemaVersion=2 vào chính scope guest; không ghi đè scope account hoặc coi đăng nhập cũ là tài khoản REST mới.

Phần cá nhân tương thích được giữ local. Công thức/nguyên liệu cũ cần được tách thành draft chờ nhập, không tự trộn vào cache REST và tự upload khi khởi động. favoriteIds và localImages được tách khỏi object công thức chia sẻ. Cần giữ bản sao để quay lại nếu đọc/chuyển đổi thất bại.

Nhập công thức/nguyên liệu cũ là thao tác **có xác nhận rõ ràng** vì dữ liệu sẽ trở thành danh mục dùng chung. Nhập nguyên liệu trước công thức để tham chiếu tồn tại. Dùng ID ổn định và kiểm tra ID để nhập lại không nhân đôi. Không tự nhập thực đơn, tủ lạnh, danh sách mua, ảnh hay dữ liệu account lên API.

Sau timeout lúc nhập, kiểm tra server theo ID trước khi gửi lại. Chỉ bỏ draft khỏi danh sách chờ sau khi xác nhận đã có bản ghi server. Bản backup cần còn để đối chiếu, kể cả khi nhập thành công.

## Danh sách bàn giao

Các ô dưới là việc cần rà soát trước nộp; không phải báo cáo mọi kiểm thử đã đạt.

- [ ] Đối chiếu nguồn và commit, kiểm tra giấy phép/quyền dùng nguồn.
- [ ] Xác nhận app không cần biến Supabase/Google/Gemini để khởi động.
- [ ] Kiểm tra UI → controller → repository → API/SQLite.
- [ ] Chạy lint/test backend và giữ log kết quả.
- [ ] Chạy Flutter analyze/test/build trên commit cuối.
- [ ] Chạy Android online/offline/error/empty/rotation/resize và ghi bằng chứng.
- [ ] Thử nâng cấp guest v1 và nhập có xác nhận nhiều lần bằng fixture.
- [ ] Đọc lại docs so với implementation cuối.
- [ ] Sinh viên bổ sung “đã giữ/đã kiểm chứng” vào AI log.
- [ ] Nhóm tự điền Team, Contribution và xác nhận tỷ lệ bằng chứng thật.

## Rollback và giới hạn

Không dùng reset API làm cách khắc phục lỗi app khi chưa sao lưu runtime. Khi có lỗi migration, giữ DB cũ/bản sao, ghi nhận lỗi và dừng nhập; không tự xóa để tạo dữ liệu trống.

Bản chuyển đổi không cung cấp dữ liệu cá nhân đa thiết bị, phân quyền danh mục hoặc server triển khai production. Nếu bổ sung các mục này sau này, cần một thiết kế xác thực, quyền và đồng bộ riêng.
