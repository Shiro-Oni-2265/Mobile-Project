# Chuẩn bị bảo vệ cá nhân

Mỗi sinh viên tự chọn phần mình thực sự sở hữu và hiểu; bảng này không phân công hoặc xác nhận công lao. Cần đọc mã đã dùng AI hỗ trợ, chạy demo và tự giải thích trước khi ghi vào Contribution.

## Demo ngắn đề xuất

1. Khởi động backend và app, mở danh mục để chỉ ra dữ liệu thật từ GET.
2. Tạo công thức mới, xem kết quả POST; sửa/xóa bản thường hoặc sao chép bản mẫu.
3. Thêm món vào thực đơn, tạo danh sách mua và nhập một lô tủ lạnh.
4. Bật airplane mode, đọc công thức đã cache, sửa dữ liệu cá nhân rồi mở lại app.
5. Chỉ ra cảnh báo lỗi/retry; giải thích trường hợp lần đầu chưa có cache.
6. Nếu demo migration, dùng fixture giả và chỉ nhập sau khi người dùng xác nhận.

Chỉ trình diễn thao tác đã chuẩn bị và kiểm tra thật. Không nói các kịch bản chưa chạy đã đạt.

## Câu hỏi và điểm cần giải thích

| Câu hỏi | Cần lần theo mã/ý chính |
|---|---|
| Refresh đi qua đâu? | Widget gọi AppController; KitchenRepository gọi RecipeApi; JSON → model → cache LocalStore → notifyListeners → UI |
| State nằm ở đâu? | ChangeNotifier được Riverpod cung cấp; Notebook lưu bền trong SQLite; state điều hướng/form có vòng đời riêng |
| Vì sao cần repository? | Giữ HTTP/SQLite ngoài View; tập trung quyết định cache và lỗi; thay data source dễ hơn |
| Vì sao chọn ChangeNotifier? | Ít khái niệm, phù hợp quy mô; đánh đổi controller lớn và phạm vi rebuild |
| Offline làm gì được? | Đọc cache đã có, chỉnh thực đơn/tủ lạnh/mua sắm/tùy chọn/yêu thích/ảnh; ghi danh mục cần online |
| Error khác empty thế nào? | Empty là phản hồi hợp lệ rỗng; error là không lấy được kết quả. Cache cũ không làm lỗi refresh biến thành success |
| Vì sao không tự gửi lại POST sau timeout? | Server có thể đã ghi; UUID ổn định và GET kiểm tra ID giúp tránh trùng |
| Danh mục có riêng tư không? | Không auth; công thức/nguyên liệu dùng chung. Yêu thích, ảnh, kế hoạch chỉ local |
| Vì sao snapshot món trong thực đơn? | Sửa/xóa món gốc không làm bữa biến mất; đổi dữ liệu nguyên liệu vẫn có thể đổi dinh dưỡng |
| Vì sao không đổi ml thành g? | Thiếu khối lượng riêng; chỉ đổi cùng loại đơn vị, hoặc có gramsPerPiece cho quả/cái |
| Gợi ý có dùng AI không? | Không; lọc tùy chọn và tính điểm theo tỷ lệ có sẵn, sắp hết hạn, thời gian |
| Vì sao sample không sửa được? | Quy tắc UI; sao chép tạo ID mới. Mock API không có bảo vệ server tương ứng |
| Ảnh lưu ở đâu? | File trên thiết bị, map theo ID; không gửi path vào payload REST |
| Có migration không? | Sao lưu guest v1; giữ local; draft chỉ nhập recipe/ingredient sau xác nhận; không tự nhập account |
| Vì sao emulator không dùng localhost? | localhost là emulator; 10.0.2.2 trỏ về máy host Android emulator |

## Bài tập thay đổi tại chỗ

- Đổi thông báo lỗi mạng và chỉ ra đường retry.
- Thêm bộ lọc thời gian nấu mà không gọi API trong widget.
- Thêm trường công thức: model/fromJson/toJson → payload REST → form → validation → seed nếu cần.
- Thay trọng số ưu tiên nguyên liệu sắp hết hạn; giải thích tác động bằng dữ liệu ví dụ.
- Tìm lỗi đổi đơn vị hoặc nhân khẩu phần trong hàm shoppingFor.
- Thêm trạng thái empty có nút bỏ bộ lọc.
- Viết/đọc một test có ý nghĩa cho timeout, cache hoặc snapshot; nêu rõ mock không thay thế kiểm thử Android.

## Những điều cần tự xác nhận

Đọc git diff, chạy phần mình nhận và tự ghi nhật ký AI. Ghi rõ phần AI tạo, phần giữ lại và cách kiểm chứng. Không học thuộc câu trả lời mà chưa tìm được file/phương thức tương ứng. Theo INSTRUCTION.md, phần không giải thích được sẽ ảnh hưởng điểm kể cả app chạy.
