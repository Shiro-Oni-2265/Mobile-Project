# Kiểm thử và demo NauGi

## Kết quả kiểm tra ngày 19/10/2026

- Flutter 3.47.7 / Dart 3.13.5: `flutter analyze` không có vấn đề.
- 27 unit/widget tests đạt, gồm biểu mẫu tạo công thức và dinh dưỡng.
- Deno kiểm tra kiểu Edge Function thành công, 2 kiểm thử logic AI đạt.
- 1 integration test đạt trên máy ảo Android Medium_Phone: SQLite thật, khôi phục sổ tay,
  tính mua sắm sau đối chiếu tủ lạnh và đánh dấu đã mua qua UI.
- Build APK release thành công (khoảng 61,5 MB), đã cài và khởi động trên máy ảo;
  không ghi nhận lỗi AndroidRuntime/flutter trong lần mở lạnh.
- Ảnh giao diện home đã kiểm tra tại `docs/screenshots/home.png`.
- Chưa nghiệm thu Supabase/Google/SMTP/Gemini thật, SQL RLS trên dự án thật và lịch thông báo dài hạn
  trên điện thoại vì chưa có cấu hình dịch vụ của nhóm. Các kiểm thử cloud hiện dùng HTTP/storage giả lập.

## Kiểm thử tự động

`flutter test` gồm tính khẩu phần, dinh dưỡng thiếu dữ liệu, đơn vị, tồn kho nhiều lô, hạn bao gồm cả ngày,
gợi ý sở thích/thời gian, snapshot, guest offline, ghi thất bại, nhập guest và xung đột cloud giả lập,
AI lỗi/mã bịa và widget từ welcome đến dinh dưỡng.

`flutter test integration_test/guest_flow_test.dart -d <device-id>` dùng SQLite thật trong database riêng
`naugi_integration.db`, không xóa sổ tay `naugi.db`. Kiểm tra lưu/khôi phục, thực đơn,
đối chiếu trứng trong tủ lạnh, mua sắm và đánh dấu đã mua qua giao diện.

`deno test supabase/functions/suggest-recipes/logic_test.ts` kiểm tra bộ lọc máy chủ và output AI.
`deno check supabase/functions/suggest-recipes/index.ts` kiểm tra kiểu của hàm.

`psql <connection-string> -v ON_ERROR_STOP=1 -f supabase/tests/rls.sql` chỉ chạy trên Supabase thử nghiệm
sau migration; kiểm tra RLS, ảnh, revision và quota, rồi rollback. Chưa thay thế được nghiệm thu Storage có ảnh thật.

## Kịch bản demo khách

1. Mở ứng dụng → Tiếp tục với tư cách khách.
2. Công thức → Trứng sốt cà chua → xem nguyên liệu và dinh dưỡng cho 2 người, đổi 4 người.
3. Sao chép vào sổ tay, sửa ghi chú, yêu thích, mở lại để xác minh lưu.
4. Tủ lạnh → thêm 2 quả trứng với hạn ngày mai; thêm cà chua với hạn đã qua.
5. Gợi ý theo nguyên liệu → kiểm tra ưu tiên trứng và không tính cà chua hết hạn.
6. Thêm món vào bữa tối cho 4 người. Mở thực đơn và xem tổng dinh dưỡng.
7. Mua sắm → tạo từ hôm nay → bật trừ tủ lạnh. Với 3 quả/2 người, cần 6 quả/4 người,
   đang có 2 quả thì cần mua 4 quả. Xác nhận rồi đánh dấu đã mua.
8. Bật chế độ máy bay, thêm/sửa công thức khách, đóng và mở lại để kiểm tra lưu cục bộ.
9. Vào cài đặt qua Tài khoản, bật nhắc hạn và cho phép thông báo. Bản debug có nút thử sau khoảng một phút;
   hệ điều hành có thể trì hoãn báo thức không chính xác.

## Nghiệm thu dịch vụ thật sau cấu hình

- Đăng ký email, xác nhận, đăng nhập, đặt lại mật khẩu bằng deep link.
- Đăng nhập Google qua trình duyệt trên cả debug và release.
- Nhập guest vào tài khoản mới; đăng xuất rồi đăng nhập lại xác minh máy chủ.
- Nhập guest vào tài khoản đã có món: không mất món cũ; thử gián đoạn và nhập lại, không nhân đôi.
- Hai tài khoản khác nhau không thấy dữ liệu/ảnh của nhau, gồm truy cập trực tiếp API.
- Hai thiết bị cùng tài khoản: sửa từ bản revision cũ phải báo lỗi, tải lại trước khi lưu tiếp.
- Mất mạng khi dùng tài khoản: chỉ xem bản lưu, không sửa hoặc đánh dấu mua; kết nối lại và Đồng bộ.
- AI chọn món hợp bộ lọc và thêm món chỉ sau xác nhận. Tạm bỏ cấu hình model hoặc chạm quota ở môi trường thử:
  báo không khả dụng, gợi ý độc lập và thực đơn/mua sắm vẫn hoạt động.
- Ảnh riêng tải trên thiết bị thứ hai, ảnh đã tải có thể xem offline; đăng xuất xóa cache tài khoản.
- Từ chối thông báo không làm ứng dụng lỗi; sửa/xóa lô phải cập nhật/hủy lịch.
- Thực đơn đã lưu còn nguyên công thức khi công thức gốc được sửa/xóa.

Các kiểm thử giả lập không chứng minh OAuth, SMTP, chính sách DB hoặc Gemini trên dự án thật hoạt động;
phải ghi riêng kết quả các bước này khi nhóm đã cấu hình dịch vụ.
