# Kế hoạch NauGi đã chốt

Đồ án Android, 2 người, lịch mục tiêu 8 tuần. Không phát hành lên cửa hàng.
Flutter + Supabase + Gemini; tiếng Việt, giao diện sáng xanh lá/kem, khoảng 20 món Việt mẫu.

## Phạm vi

1. Khách không cần đăng nhập, lưu dữ liệu và chỉnh sửa offline. Tài khoản email/Google,
   đồng bộ riêng, cache chỉ đọc khi offline, chuyển khách sau xác nhận và chống nhập trùng.
2. Công thức cá nhân có ảnh, nguyên liệu, các bước, ghi chú, danh mục, tìm kiếm và yêu thích.
   Mẫu chỉ đọc, sao chép để sửa. Điều chỉnh khẩu phần không thay công thức gốc.
3. Thực đơn tuần sáng/trưa/tối, nhiều món, đổi ngày/bữa/khẩu phần hoặc thay món.
   Lưu bản chụp công thức để chỉnh sửa món gốc không làm hỏng lịch.
4. Mua sắm từ khoảng ngày, gộp đơn vị tương thích, xem trước và xác nhận trừ nguyên liệu sẵn có;
   danh sách độc lập, thêm/sửa/xóa và đánh dấu đã mua.
5. Tủ lạnh theo lô, lượng và hạn, cập nhật thủ công; nhắc khoảng 8 giờ trước hạn 2 ngày và ngày hết hạn.
6. Dinh dưỡng/calo ước tính: cả món, mỗi khẩu phần, bữa và ngày; kcal/protein/carb/fat,
   cập nhật theo dữ liệu nguyên liệu và khẩu phần; luôn hiện phần thiếu dữ liệu.
7. Gợi ý độc lập theo nguyên liệu, hạn, sở thích và thời gian; AI cho tài khoản, chỉ chọn tối đa 5 món trong thư viện.
   AI lỗi thông báo không khả dụng và cho thử lại; không tự thay bằng gợi ý quy tắc.

Không có cộng đồng, tự tạo công thức bằng AI, tính mục tiêu cân nặng, gia đình nhiều tài khoản,
tự cập nhật tồn khi mua/nấu, hoặc ghi offline cho tài khoản đồng bộ.

## Lộ trình

| Tuần | Đầu ra |
|---|---|
| 1 | Môi trường, prototype, dữ liệu, xác minh dịch vụ thật |
| 2 | Điều hướng, tài khoản, guest, lưu trữ và phân quyền |
| 3 | Công thức, ảnh và danh mục dinh dưỡng |
| 4 | Thực đơn và dinh dưỡng theo bữa/ngày |
| 5 | Tủ lạnh và mua sắm |
| 6 | Gợi ý quy tắc, AI, sở thích và nhắc hạn |
| 7 | Kiểm thử offline, nhập guest, xung đột và quyền |
| 8 | Nghiệm thu Android, APK, tài liệu, demo |

Người 1 phụ trách Flutter/UI; người 2 phụ trách Supabase/dữ liệu/AI. Cùng chạy luồng xuyên suốt mỗi tuần.
Hạn nộp chính xác và tiêu chí riêng giảng viên chưa được cung cấp.

## Bàn giao và phụ thuộc

Mã nguồn, APK đồ án, migrations/seed, cấu hình mẫu, sơ đồ dữ liệu, hướng dẫn thiết lập, kiểm thử và demo.
Tích hợp cloud thật phụ thuộc project, email/Google OAuth và API key do nhóm cấu hình;
chỉ sử dụng hạn mức miễn phí, không tự bật billing.
